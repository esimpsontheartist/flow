import FractionFixedPriceSale from "../../contracts/FractionFixedPriceSale.cdc"

pub struct ListingData {
    pub let saleId: UInt64
    pub let vaultId: UInt256
    pub let curator: Address
    pub let amount: UInt256
    pub let salePrice: UFix64
    pub let salePaymentType: Type
    pub let receiver: Address

    init(
            _ saleId: UInt64,
            _ vaultId: UInt256, 
            _ curator: Address,
            _ amount: UInt256, 
            _ salePrice: UFix64,
            _ salePaymentType: Type,
            _ receiver: Address
        ) {
            self.saleId = saleId
            self.vaultId = vaultId
            self.curator = curator
            self.amount = amount
            self.salePrice = salePrice
            self.salePaymentType = salePaymentType
            self.receiver = receiver
        }
}

pub fun main(listingId: UInt64): ListingData {


    let listing = FractionFixedPriceSale.getListing(saleId: listingId)

    let ListingData = ListingData(
        listing.saleId,
        listing.vaultId,
        listing.curator,
        listing.amount,
        listing.salePrice,
        listing.salePaymentType,
        listing.receiver
    )

    return ListingData

}