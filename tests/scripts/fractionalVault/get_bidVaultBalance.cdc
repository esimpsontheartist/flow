import FractionalVault from "../../contracts/FractionalVault.cdc"

// This scripts returns the balance for a FractionalVault's bidVault,
// where the bids are stored
pub fun main(address: Address, vaultId: UInt64): UFix64 {

    //Vault that will be returned
    let vaultCollection = getAccount(address).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
        ?? panic("could not get a reference to the fractional vault")
    
    let vault = vaultCollection.borrowVault(id: vaultId) ?? panic("could not borrow a reference to the bid vault")
    let bidVault = vault.vaultBalance()
    return bidVault.balance

}