import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import ExampleNFT from "../../contracts/lib/ExampleNFT.cdc"


// This script returns the size of an account's KittyItems collection.

pub fun main(address: Address): Int {
    let account = getAccount(address)

    let collectionRef = account.getCapability(ExampleNFT.CollectionPublicPath)!
        .borrow<&{NonFungibleToken.CollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")
    
    return collectionRef.getIDs().length
}
