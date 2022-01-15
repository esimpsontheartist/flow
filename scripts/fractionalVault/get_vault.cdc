import FractionalVault from "../../contracts/FractionalVault.cdc"


pub struct Vault {
  pub let vaultId: UInt64
  pub let auctionEnd : UFix64?
  pub let auctionLength : UFix64
  pub let livePrice : UFix64?
  pub let winning : Address?
  pub let auctionState : UInt8
  pub let address: Address //Address where the vault is stored

  init(
      vaultId: UInt64, 
      auctionEnd: UFix64?, 
      auctionLength: UFix64,
      livePrice: UFix64?,
      winning: Address?,
      auctionState: UInt8,
      address: Address
    ) {
    self.vaultId = vaultId
    self.auctionEnd = auctionEnd
    self.auctionLength = auctionLength
    self.livePrice = livePrice
    self.winning = winning
    self.auctionState = auctionState
    self.address = address
  }
}

// This scripts returns a vault from the path
pub fun main(address: Address, vaultId: UInt64): Vault? {
    //Vault that will be returned
    if let vaultCollection = getAccount(address).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            return Vault( 
                  vaultId: vaultId, 
                  auctionEnd: vault.getAuctionEnd(), 
                  auctionLength: vault.auctionLength,
                  livePrice: vault.getLivePrice(),
                  winning: vault.getWinning()?.address,
                  auctionState: vault.getAuctionState().rawValue,
                  address: address
                )
        }
    }
    return nil

}