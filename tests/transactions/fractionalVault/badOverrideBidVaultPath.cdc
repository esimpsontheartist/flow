import FractionalVault from "../../contracts/FractionalVault.cdc"

//An example transaction for the administrator to override a vault's Path
transaction(address: Address, vaultId: UInt64) {

    let admin: &FractionalVault.Administrator

    let vault: &{FractionalVault.PublicVault}

    prepare(account: AuthAccount) {
        let collectionCapability = getAccount(address).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.vault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")

        self.admin = account.borrow<&FractionalVault.Administrator>(from: FractionalVault.AdministratorStoragePath)
        ?? panic("could not borrow a reference for the Fractional")

    }

    execute {
        self.admin.overrideVaultPath(vault: self.vault, path: /public/fusdTokenReceiver)
    }
}