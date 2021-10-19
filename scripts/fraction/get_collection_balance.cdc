import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"


// This script returns the size of an account's Fraction collection.

pub fun main(address: Address): UInt256 {
    let account = getAccount(address)

    let collectionRef = account.getCapability(Fraction.CollectionPublicPath)!
        .borrow<&{Fraction.CollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")
    
    return collectionRef.balance()
}