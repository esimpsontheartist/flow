import FractionalVault from "../../contracts/FractionalVault.cdc"

// A transaction end an auction after the timer has run out
transaction(vaultAddress: Address, vaultId: UInt256,) {
    execute {
        let collectionCapability = getAccount(vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        let fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")
        
        //call the end() function
        fractionalVault.end()
        
    }
}