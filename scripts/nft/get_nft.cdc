import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"

pub struct AccountItem {
  pub let itemID: UInt64
  pub let resourceID: UInt64
  pub let owner: Address

  init(itemID: UInt64, resourceID: UInt64, owner: Address) {
    self.itemID = itemID
    self.resourceID = resourceID
    self.owner = owner
  }
}

pub fun main(address: Address, itemID: UInt64): AccountItem? {
  if let collection = getAccount(address).getCapability<&ExampleNFT.Collection{NonFungibleToken.CollectionPublic, ExampleNFT.CollectionPublic}>(ExampleNFT.CollectionPublicPath).borrow() {
    let item = collection.borrowNFT(id: itemID) 
    return AccountItem(itemID: itemID, resourceID: item.uuid, owner: address)
    
  }
  return nil
}
