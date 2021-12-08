import FractionFixedPriceSale from "../../contracts/FractionFixedPriceSale.cdc"

pub struct FractionData {
    pub let vaultId: UInt256
    pub let name: String
    pub let thumbnail: String
    pub let description: String
    pub let source: String
    pub let media: String
    pub let contentType: String
    pub let protocol: String

    init(
	    _ vaultId: UInt256,
	    _ name: String,
	    _ thumbnail: String,
	    _ description: String,
	    _ source: String,
	    _ media: String,
	    _ contentType: String,
	    _ protocol: String
	) {
        self.vaultId = vaultId
        self.name = name 
        self.thumbnail = thumbnail 
        self.description = description 
        self.source = source 
        self.media = media 
        self.contentType = contentType
        self.protocol = protocol 
    }
}

pub fun main(listingId: UInt64): FractionData {

    let listing = FractionFixedPriceSale.getListing(saleId: listingId)

    let sale = FractionData(
        listing.vaultId,
        listing.fractionData.name,
        listing.fractionData.thumbnail,
        listing.fractionData.description,
        listing.fractionData.source,
        listing.fractionData.media,
        listing.fractionData.contentType,
        listing.fractionData.protocol
    )
    
    return sale

}