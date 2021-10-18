import Fraction from "../../contracts/Fraction.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

// This scripts returns the IDs of the fractions currently held inside a vault
pub fun main(vaultAddress: Address, vaultId: UInt256): [UInt64]? {

    //Vault that will be returned
    if let vaultCollection = getAccount(vaultAddress).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            let underlying = vault.borrowCollection()
            return underlying.getIDs()
        }
    }
    return nil

}