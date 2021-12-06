import FlowToken from "../../contracts/FlowToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FractionFixedPriceSale from "../../contracts/FractionFixedPriceSale.cdc"

transaction(
    listingId: UInt64,
) {

    //Collection to carry out the sale
    let fixedSaleCollection: &FractionFixedPriceSale.FixedSaleCollection

    prepare(signer: AuthAccount){
        self.fixedSaleCollection = signer.borrow<&FractionFixedPriceSale.FixedSaleCollection>(from: FractionFixedPriceSale.CollectionStoragePath)
        ?? panic("could not borrow a reference for the fixed price sale")
    }

    execute {
        self.fixedSaleCollection.cancelListing(listingId: listingId)
    }
}