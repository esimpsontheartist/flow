import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"
import WrappedCollection from "../../contracts/WrappedCollection.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

//Transaction to mint a new vault
transaction(
    nftIds: [UInt64], 
    fractionCurator: Address,
    maxSupply: UInt256,
) {
    
    //An example NFT collection
    let collection: &WrappedCollection.Collection
    
    let curator: Capability<&Fraction.BulkCollection>
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {
        
        self.collection = account.borrow<&WrappedCollection.Collection>(from: WrappedCollection.CollectionStoragePath) 
        ?? panic("could not load collection")

        self.curator = account.getCapability<&Fraction.BulkCollection>(Fraction.CollectionPrivatePath)
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
        
        FractionalVault.mintVault(
            collection: <- wrappedCollection, 
            collectionType: Type<@WrappedCollection.Collection>(),
            bidVault: <- FlowToken.createEmptyVault(),
            bidVaultType: Type<@FlowToken.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply,
            name: "Fractional Test Vault",
            description: "A vault to test out fractional functionality"
        )
    }
}


