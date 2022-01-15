import FlowToken from "../../contracts/FlowToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FixedPriceSale from "../../contracts/FixedPriceSale.cdc"

transaction(
    listingId: UInt64,
) {

    let fixedSaleCollection: &FixedPriceSale.FixedSaleCollection

    prepare(signer: AuthAccount){
        self.fixedSaleCollection = signer.borrow<&FixedPriceSale.FixedSaleCollection>(from: FixedPriceSale.CollectionStoragePath)
        ?? panic("could not borrow a reference for the fixed price sale")
    }

    execute {
        self.fixedSaleCollection.cancelListing(listingId: listingId)
    }
}