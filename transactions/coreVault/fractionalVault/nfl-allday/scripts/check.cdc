import NonFungibleToken from "../../../../../contracts/core/NonFungibleToken.cdc"
import AllDay from "../../../../../contracts/third-party/AllDay.cdc"

// check nfl collection is available on a given address

pub fun main(address: Address): Bool {
    return getAccount(address)
        .getCapability<&{AllDay.MomentNFTCollectionPublic}>(AllDay.CollectionPublicPath)
        .check()
}
