import FractionalVault from "../../../contracts/FractionalVault.cdc"
import Fraction from "../../../contracts/Fraction.cdc"

//Transaction to mint a new vault
transaction(recipient: Address, vaultId: UInt64, amount: UInt256) {

    let fractionCollection: &{Fraction.BulkCollectionPublic}
    let fractionalVaultCollection: &FractionalVault.VaultCollection

    prepare(account: AuthAccount) {
        //Signer must be the owner of the Vault
        self.fractionalVaultCollection = account.borrow<&FractionalVault.VaultCollection>(from: FractionalVault.VaultStoragePath)
        ?? panic("could not borrow a reference for the fractional vault collection")

        self.fractionCollection = getAccount(recipient).getCapability<&{Fraction.BulkCollectionPublic}>(Fraction.CollectionPublicPath).borrow()
        ?? panic("could not borrow a capability for the fraction collection")
        
    }
    execute {
        let minter = self.fractionalVaultCollection.borrowMinter(id: vaultId) 
        ?? panic("borrowMinter returned nil")
        let fractions <- minter.mint(amount: amount)
        
        for id in fractions.getIDs() {
            self.fractionCollection.deposit(token: <- fractions.withdraw(withdrawID: id))
        }

        destroy fractions
    }
}