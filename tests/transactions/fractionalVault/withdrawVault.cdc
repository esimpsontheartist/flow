import CoreVault from "../../contracts/CoreVault.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

// A transaction to be used by vault owner to withdraw the core vault 
// out of the fractional vault
transaction(vaultId: UInt64) {
    //Collection that stores the vault
    let fractionalVaultCollection: &FractionalVault.VaultCollection

    prepare(account: AuthAccount) {
        
        self.fractionalVaultCollection = account.borrow<&FractionalVault.VaultCollection>(from: FractionalVault.VaultStoragePath)
        ?? panic("could not borrow a refrence to the")
        
        self.fractionalVaultCollection.vaults[vaultId]?.withdrawVault()
    }
}