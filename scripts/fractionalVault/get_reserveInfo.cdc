import FractionalVault from "../../contracts/FractionalVault.cdc"

pub struct ReserveInfo {
  pub let voting: UInt256
  pub let reserve: UFix64

  init(
      voting: UInt256,
      reserve: UFix64
    ) {
    self.voting = voting
    self.reserve = reserve
  }
}

// This scripts returns the reservePrice for a given vault ID
pub fun main(vaultId: UInt64): ReserveInfo {
    let reserveInfo = FractionalVault.reservePrice(vaultId)
    return ReserveInfo(voting: reserveInfo.voting, reserve: reserveInfo.reserve)
}