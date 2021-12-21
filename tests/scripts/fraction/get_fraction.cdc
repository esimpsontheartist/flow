import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"

pub struct AccountItem {
  pub let itemID: UInt64
  pub let vaultId: UInt256
  pub let resourceID: UInt64
  pub let owner: Address

  init(itemID: UInt64, vaultId: UInt256, resourceID: UInt64, owner: Address) {
    self.itemID = itemID
    self.vaultId = vaultId
    self.resourceID = resourceID
    self.owner = owner
  }
}

pub fun main(address: Address, itemID: UInt64): AccountItem? {
  if let collection = getAccount(address).getCapability<&Fraction.BulkCollection{NonFungibleToken.CollectionPublic, Fraction.BulkCollectionPublic}>(Fraction.CollectionPublicPath).borrow() {
    let item = collection.borrowFraction(id: itemID) 
    return AccountItem(itemID: itemID, vaultId: item!.vaultId, resourceID: item!.uuid, owner: address)
  }

  return nil
}
