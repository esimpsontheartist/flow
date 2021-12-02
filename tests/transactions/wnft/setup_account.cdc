import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import WrappedCollection from "../../contracts/WrappedCollection.cdc"

// This transaction configure an account to hold a vault

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&WrappedCollection.Collection>(from: WrappedCollection.CollectionStoragePath) == nil {
             // create a new empty collection
            let collection <- WrappedCollection.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: WrappedCollection.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&WrappedCollection.Collection{WrappedCollection.CollectionPublic, NonFungibleToken.CollectionPublic}>(WrappedCollection.CollectionPublicPath, target: WrappedCollection.CollectionStoragePath)
        }
    }
}