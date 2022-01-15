import CoreVault from "../../contracts/CoreVault.cdc"

pub fun main(address: Address): [UInt64] {
    if let vaultCollection = getAccount(address).getCapability<&CoreVault.VaultCollection{CoreVault.CollectionPublic}>(CoreVault.CollectionPublicPath).borrow() {
        return vaultCollection.getIDs()
    }
    return []
}