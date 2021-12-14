import NonFungibleToken from "../../../../contracts/core/NonFungibleToken.cdc"
import AllDay from "../../../../contracts/third-party/AllDay.cdc"

// This scripts returns data for an NFL All Day NFT

pub fun main(address: Address, id: UInt64): &AnyResource {
    let account = getAccount(address)

    let collectionRef = account.getCapability(AllDay.CollectionPublicPath)
        .borrow<&{AllDay.MomentNFTCollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")
    
    let nft = collectionRef.borrowMomentNFT(id: id)
        ?? panic("Couldn't borrow momentNFT")

    return nft
}