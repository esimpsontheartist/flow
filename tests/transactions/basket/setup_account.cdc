import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Basket from "../../contracts/Basket.cdc"

// This transaction configure an account to hold a vault

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&Basket.Collection>(from: Basket.CollectionStoragePath) == nil {
             // create a new empty collection
            let collection <- Basket.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: Basket.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&Basket.Collection{Basket.CollectionPublic, NonFungibleToken.CollectionPublic}>(Basket.CollectionPublicPath, target: Basket.CollectionStoragePath)
        }
    }
}