import ChainmonstersRewards from "../../../../../contracts/third-party/ChainmonstersRewards.cdc"

pub fun main(): [ChainmonstersRewards.Reward] {
    return ChainmonstersRewards.getAllRewards()
}
