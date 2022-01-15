import FixedPriceSale from "../../contracts/FixedPriceSale.cdc"

pub struct Listing {
    pub let saleId: UInt64
    pub let vaultId: UInt64
    pub let uri: String
    pub let curator: Address
    pub let name: String
    pub let description: String
    pub let amount: UInt256
    pub let salePrice: UFix64
    pub let salePaymentType: Type
    pub let receiver: Address

    init(
	    _ saleId: UInt64,
        _ vaultId: UInt64,
        _ uri: String,
        _ curator: Address,
        _ name: String,
        _ description: String,
        _ amount: UInt256,
        _ salePrice: UFix64,
        _ salePaymentType: Type,
        _ receiver: Address
	) {
        self.saleId = saleId
        self.vaultId = vaultId
        self.uri = uri
        self.curator = curator
        self.name = name
        self.description = description
        self.amount = amount
        self.salePrice = salePrice
        self.salePaymentType = salePaymentType
        self.receiver = receiver
    }
}

pub fun main(listingId: UInt64): Listing {

    let listing = FixedPriceSale.getListing(id: listingId) ?? panic("no such listings")

    let sale = Listing(
        listing.id,
        listing.vaultId,
        listing.fractionData.uri,
        listing.fractionData.curator,
        listing.fractionData.name,
        listing.fractionData.description,
        listing.amount,
        listing.salePrice,
        listing.salePaymentType,
        listing.receiver
    )
    
    return sale

}