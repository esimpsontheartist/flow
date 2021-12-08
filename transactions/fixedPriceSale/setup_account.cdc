import FractionFixedPriceSale from "../../contracts/FractionFixedPriceSale.cdc"

// This transaction configures an account to hold fixed price sales

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&FractionFixedPriceSale.FixedSaleCollection>(from: FractionFixedPriceSale.CollectionStoragePath) == nil {
             // create a new empty collection
            let collection <- FractionFixedPriceSale.createFixedPriceSaleCollection()
            
            // save it to the account
            signer.save(<-collection, to: FractionFixedPriceSale.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&FractionFixedPriceSale.FixedSaleCollection{FractionFixedPriceSale.FixedSaleCollectionPublic}>(FractionFixedPriceSale.CollectionPublicPath, target: FractionFixedPriceSale.CollectionStoragePath)
        }
    }
}