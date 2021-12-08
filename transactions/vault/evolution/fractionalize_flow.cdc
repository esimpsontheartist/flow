import Evolution from "../../../contracts/third-party/Evolution.cdc"
import FlowToken from "../../../contracts/core/FlowToken.cdc"
import FungibleToken from "../../../contracts/core/FungibleToken.cdc"
import NonFungibleToken from "../../../contracts/core/NonFungibleToken.cdc"
import FractionalVault from "../../../contracts/FractionalVault.cdc"
import Fraction from "../../../contracts/Fraction.cdc"

transaction(
    nftIds: [UInt64], 
    fractionCurator: Address,
    maxSupply: UInt256
) {
    //Collection to pull the MotoGP Cards from
    let evolutionProvider: &Evolution.Collection
    //Curator capability to mint or list fractions
    let curator: Capability<&Fraction.Collection>

    prepare(account: AuthAccount) {

        self.evolutionProvider = account.borrow<&Evolution.Collection>(from: /storage/f4264ac8f3256818_Evolution_Collection) 
        ?? panic("could not borrow a reference to the MotoGP collection")

        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        //Evolution collectibles to fractionalize
        let evolutionCollection <- self.evolutionProvider.batchWithdraw(ids: nftIds)

        FractionalVault.mintVault(
            collection: <- evolutionCollection, 
            collectionType: Type<@Evolution.Collection>(),
            bidVault: <- FlowToken.createEmptyVault(),
            bidVaultType: Type<@FlowToken.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply
        )
    }   
}