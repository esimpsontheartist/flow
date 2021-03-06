import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"


// This script returns the size of an account's Fraction collection.

pub fun main(address: Address): UInt256 {
    let account = getAccount(address)
    log("getCollectionBalance!!!!!!!")
    let collectionRef = account.getCapability(Fraction.CollectionPublicPath)!
        .borrow<&{Fraction.BulkCollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")
    
    return UInt256(collectionRef.getIDs().length)
}
