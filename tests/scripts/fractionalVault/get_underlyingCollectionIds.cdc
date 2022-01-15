import FractionalVault from "../../contracts/FractionalVault.cdc"

// This scripts returns the uuids for a vault's underlying collection
pub fun main(address: Address, vaultId: UInt64): [UInt64] {

    //Vault that will be returned
    if let vaultCollection = getAccount(address).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            let underlying = vault.borrowUnderlying()
            return underlying.getIDs()
        }
    }
    return []

}
 