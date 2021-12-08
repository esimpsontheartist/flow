import FractionFixedPriceSale from "../../contracts/FractionFixedPriceSale.cdc"

pub fun main(address: Address): [UInt64] {
    let account = getAccount(address)
    
    let collectionRef = account.getCapability(FractionFixedPriceSale.CollectionPublicPath)!.borrow<&{FractionFixedPriceSale.FixedSaleCollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")

    return collectionRef.getIDs()
}