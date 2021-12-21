import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"


// This script returns the size of an account's Fraction collection.

pub fun main(address: Address, vaultId: UInt256): [UInt64] {
    let account = getAccount(address)
    log("getFractionsByVault!!!!!!")
    let collectionRef = account.getCapability(Fraction.CollectionPublicPath)!.borrow<&{Fraction.BulkCollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")
    
    return collectionRef.getIDsByVault(vaultId: vaultId)
}