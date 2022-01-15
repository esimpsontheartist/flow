import FractionalVault from "../../contracts/FractionalVault.cdc"

// This scripts returns the uuids for a vault's underlying collection
pub fun main(address: Address): [UInt64] {

    //Vault that will be returned
    if let vaultCollection = getAccount(address).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
        return vaultCollection.getIDs()
    }
    return []

}