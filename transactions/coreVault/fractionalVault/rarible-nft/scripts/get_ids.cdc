import NonFungibleToken from "../../../../../contracts/core/NonFungibleToken.cdc"
import RaribleNFT from "../../../../../contracts/third-party/RaribleNFT.cdc"

// Take RaribleNFT ids by account address
//
pub fun main(address: Address): [UInt64]? {
    let collection = getAccount(address)
        .getCapability<&{NonFungibleToken.CollectionPublic}>(RaribleNFT.collectionPublicPath)
        .borrow()
        ?? panic("NFT Collection not found")
    return collection.getIDs()
}
