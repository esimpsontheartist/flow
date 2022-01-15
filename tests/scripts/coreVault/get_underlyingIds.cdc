import CoreVault from "../../contracts/CoreVault.cdc"

pub fun main(address: Address, vaultId: UInt64): [UInt64] {
    if let vaultCollection = getAccount(address).getCapability<&CoreVault.VaultCollection{CoreVault.CollectionPublic}>(CoreVault.CollectionPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            return vault.borrowPublicCollection().getIDs()
        }
    }
    return []
}