import Art from "../../../contracts/third-party/Art.cdc"
import FUSD from "../../../contracts/core/FUSD.cdc"
import FungibleToken from "../../../contracts/core/FungibleToken.cdc"
import NonFungibleToken from "../../../contracts/core/NonFungibleToken.cdc"
import FractionalVault from "../../../contracts/FractionalVault.cdc"
import Fraction from "../../../contracts/Fraction.cdc"

transaction(
    nftIds: [UInt64], 
    fractionCurator: Address,
    maxSupply: UInt256,
    name: String, 
    description: String
) {
    //Collection to pull the MotoGP Cards from
    let artProvider: &Art.Collection
    //Curator capability to mint or list fractions
    let curator: Capability<&Fraction.Collection>

    prepare(account: AuthAccount) {

        self.artProvider = account.borrow<&Art.Collection>(from: Art.CollectionStoragePath) 
        ?? panic("could not borrow a reference to the MotoGP collection")

        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        //Evolution collectibles to fractionalize
        let artCollection <- Art.createEmptyCollection()
        //Filling the metadata array
        for id in nftIds {
            artCollection.deposit(token: <- self.artProvider.withdraw(withdrawID: id))
        }

        FractionalVault.mintVault(
            collection: <- artCollection, 
            collectionType: Type<@Art.Collection>(),
            bidVault: <- FUSD.createEmptyVault(),
            bidVaultType: Type<@FUSD.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply,
            name: name,
            description: description
        )
    }   
}