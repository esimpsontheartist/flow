import FractionalVault from "../../contracts/FractionalVault.cdc"


pub struct Vault {
  pub let vaultId: UInt256
  pub let auctionEnd : UFix64?
  pub let auctionLength : UFix64
  pub let livePrice : UFix64?
  pub let winning : Address?
  pub let auctionState : FractionalVault.State?
  pub let resourceID: UInt64
  pub let vaultAddress: Address //Address where the vault is stored

  init(
      vaultId: UInt256, 
      auctionEnd: UFix64?, 
      auctionLength: UFix64,
      livePrice: UFix64?,
      winning: Address?,
      auctionState: FractionalVault.State?,
      resourceID: UInt64, 
      vaultAddress: Address
    ) {
    self.vaultId = vaultId
    self.auctionEnd = auctionEnd
    self.auctionLength = auctionLength
    self.livePrice = livePrice
    self.winning = winning
    self.auctionState = auctionState
    self.resourceID = resourceID
    self.vaultAddress = vaultAddress
  }
}

// This scripts returns a vault from the path
pub fun main(vaultId: UInt256): Vault? {
    let vaultAddress = FractionalVault.vaultAddress
    //Vault that will be returned
    if let vaultCollection = getAccount(vaultAddress).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            return Vault( 
                  vaultId: vaultId, 
                  auctionEnd: vault.auctionEnd, 
                  auctionLength: vault.auctionLength,
                  livePrice: vault.livePrice,
                  winning: vault.winning,
                  auctionState: vault.auctionState,
                  resourceID: vault.uuid, 
                  vaultAddress: vaultAddress
                )
        }
    }
    return nil

}