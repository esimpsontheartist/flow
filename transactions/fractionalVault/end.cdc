import FractionalVault from "../../contracts/FractionalVault.cdc"

// A transaction end an auction after the timer has run out
transaction(vaultId: UInt256) {

    let fractionalVault: &FractionalVault.Vault

    prepare(signer: AuthAccount){
        let vaultAddress = FractionalVault.vaultAddress
        let collectionCapability = getAccount(vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a reference to a vault with the given id")
    }
    execute {
        //call the end() function
        self.fractionalVault.end()
        
    }
}