import FractionalVault from "../../contracts/FractionalVault.cdc"

// This scripts returns the balance for a FractionalVault's bidVault,
// where the bids are stored
pub fun main(vaultId: UInt256): UFix64 {

    let vaultAddress = FractionalVault.vaultAddress
    //Vault that will be returned
    let vaultCollection = getAccount(vaultAddress).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
        ?? panic("could not get a reference to the fractional vault")
    
    let vault = vaultCollection.borrowVault(id: vaultId) ?? panic("could not borrow a reference to the bid vault")
    let bidVault = vault.borrowBidVault()
    return bidVault.balance

}