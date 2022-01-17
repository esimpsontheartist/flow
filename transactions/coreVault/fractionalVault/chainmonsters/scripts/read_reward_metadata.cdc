import ChainmonstersRewards from "../../../../../contracts/third-party/ChainmonstersRewards.cdc"

pub fun main(rewardID: UInt32): String {
    return ChainmonstersRewards.getRewardMetaData(rewardID: rewardID) ?? panic("Reward does not exist")
}
