import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"
import WrappedCollection from "../../contracts/WrappedCollection.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

//Transaction to mint a new vault
transaction(
    nftIds: [UInt64], 
    fractionCurator: Address,
    maxSupply: UInt256
) {
    
    //An example NFT collection
    let collection: &WrappedCollection.Collection
    
    let curator: Capability<&Fraction.Collection>
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {
        
        self.collection = account.borrow<&WrappedCollection.Collection>(from: WrappedCollection.CollectionStoragePath) 
        ?? panic("could not load collection")

        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        
        //Create the WrappedCollection to be deposited into the vault
        let wrappedCollection <- WrappedCollection.createEmptyCollection()

        //withdraw the underlying
        for id in nftIds {
            wrappedCollection.deposit(token: <- self.collection.withdraw(withdrawID: id))
        }
        
        let medias: {UInt64: FractionalVault.Media} = {}
        let displays: {UInt64: FractionalVault.Display} = {}

        medias[0] = FractionalVault.Media(
            data: "https://lh3.googleusercontent.com/eseF_p4TBPq0Jauf99fkm32n13Xde_Zgsjdfy6L450YZaEUorYtDmUUHBxcxnC21Sq8mzBJ6uW8uUwYCKckyChysBRNvrWyZ6uSx",
            contentType: "image/jpeg",
            protocol: "http"
        )

        displays[0] = FractionalVault.Display(
            name: "Example Doge",
            thumbnail: "https://lh3.googleusercontent.com/eseF_p4TBPq0Jauf99fkm32n13Xde_Zgsjdfy6L450YZaEUorYtDmUUHBxcxnC21Sq8mzBJ6uW8uUwYCKckyChysBRNvrWyZ6uSx",
            description: "An example NFT for testing purposes",
            source: "ExampleNFT"
        )
        
        FractionalVault.mintVault(
            collection: <- wrappedCollection, 
            collectionType: Type<@WrappedCollection.Collection>(),
            bidVault: <- FlowToken.createEmptyVault(),
            bidVaultType: Type<@FlowToken.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply,
            medias: medias,
            displays: displays
        )
    }
}


