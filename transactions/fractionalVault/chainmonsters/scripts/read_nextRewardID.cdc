import ChainmonstersRewards from "../../../../contracts/third-party/ChainmonstersRewards.cdc"

pub fun main(): UInt32 {
    return ChainmonstersRewards.nextRewardID
}
