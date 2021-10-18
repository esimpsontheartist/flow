import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import WrappedCollection from "../../contracts/lib/WrappedCollection.cdc"

// This transaction configure an account to hold a vault

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&WrappedCollection.Collection>(from: WrappedCollection.WrappedCollectionStoragePath) == nil {
             // create a new empty collection
            let collection <- WrappedCollection.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: WrappedCollection.WrappedCollectionStoragePath)

            // create a public capability for the collection
            signer.link<&WrappedCollection.Collection{WrappedCollection.WrappedCollectionPublic}>(WrappedCollection.WrappedCollectionPublicPath, target: WrappedCollection.WrappedCollectionStoragePath)
        }
    }
}