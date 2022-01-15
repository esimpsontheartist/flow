import CoreVault from "../../contracts/CoreVault.cdc"

pub struct Vault {
  pub let vaultId: UInt64
  pub let curator: Address
  pub let collectionIds: [UInt64]
  pub let underlyingType: Type
  pub let name: String?
  pub let description: String?

  init(
      vaultId: UInt64,
      curator: Address,
      collectionIds: [UInt64],
      underlyingType: Type,
      name: String?,
      description: String?
    ) {
        self.vaultId = vaultId
        self.curator = curator
        self.collectionIds = collectionIds
        self.underlyingType = underlyingType
        self.name = name
        self.description = description
  }
}

// This scripts returns a vault from the path
pub fun main(address: Address, vaultId: UInt64): Vault? {
    //Vault that will be returned
    if let vaultCollection = getAccount(address).getCapability<&CoreVault.VaultCollection{CoreVault.CollectionPublic}>(CoreVault.CollectionPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            return Vault( 
                  vaultId: vault.uuid,
                  curator: vault.curator.address,
                  collectionIds: vault.borrowPublicCollection().getIDs(),
                  underlyingType: vault.underlyingType,
                  name: vault.name,
                  description: vault.description
            )
        }
    }
    return nil

}