import ChainmonstersRewards from "../../../../contracts/third-party/ChainmonstersRewards.cdc"



pub fun main(account: Address, id: UInt64): Bool {
    let collectionRef = getAccount(account).getCapability(/public/ChainmonstersRewardCollection)!
        .borrow<&{ChainmonstersRewards.ChainmonstersRewardCollectionPublic}>()
        ?? panic("Could not get public reward collection reference")

    return collectionRef.borrowNFT(id: id) != nil
}
