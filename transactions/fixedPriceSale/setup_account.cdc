import FixedPriceSale from "../../contracts/FixedPriceSale.cdc"

// This transaction configures an account to hold fixed price sales

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&FixedPriceSale.FixedSaleCollection>(from: FixedPriceSale.CollectionStoragePath) == nil {
             // create a new empty collection
            let collection <- FixedPriceSale.createFixedPriceSaleCollection()
            
            // save it to the account
            signer.save(<-collection, to: FixedPriceSale.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&FixedPriceSale.FixedSaleCollection{FixedPriceSale.FixedSaleCollectionPublic}>(FixedPriceSale.CollectionPublicPath, target: FixedPriceSale.CollectionStoragePath)
        }
    }
}