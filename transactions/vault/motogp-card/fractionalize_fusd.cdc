import MotoGPCard from "../../../contracts/third-party/MotoGPCard.cdc"
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
    let motoGpProvider: &MotoGPCard.Collection
    //Curator capability to mint or list fractions
    let curator: Capability<&Fraction.Collection>

    prepare(account: AuthAccount) {

        self.motoGpProvider = account.borrow<&MotoGPCard.Collection>(from: /storage/motogpCardCollection) 
        ?? panic("could not borrow a reference to the MotoGP collection")

        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        //MotoGP cards to fractionalize
        let motoGpCollection <- MotoGPCard.createEmptyCollection()
        //Metadata array
        let metadata: {UInt64: {String: AnyStruct}} = {}
        //Filling the metadata array
        for id in nftIds {
            motoGpCollection.deposit(token: <- self.motoGpProvider.withdraw(withdrawID: id))
        }

        FractionalVault.mintVault(
            collection: <- motoGpCollection, 
            collectionType: Type<@MotoGPCard.Collection>(),
            bidVault: <- FUSD.createEmptyVault(),
            bidVaultType: Type<@FUSD.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply,
            name: name, 
            description: description
        )
    }   
}