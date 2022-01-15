import FixedPriceSale from "../../contracts/FixedPriceSale.cdc"

pub fun main(address: Address): [UInt64] {
    let account = getAccount(address)
    
    let collectionRef = account.getCapability(FixedPriceSale.CollectionPublicPath)!.borrow<&{FixedPriceSale.FixedSaleCollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")

    return collectionRef.getIDs()
}