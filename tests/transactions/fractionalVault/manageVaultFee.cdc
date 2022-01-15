import FractionalVault from "../../contracts/FractionalVault.cdc"

transaction(fee: UFix64) {

    let admin: &FractionalVault.Administrator

    prepare(account: AuthAccount) {

        self.admin = account.borrow<&FractionalVault.Administrator>(from: FractionalVault.AdministratorStoragePath)
        ?? panic("could not borrow a reference for the Fractional")

    }

    execute {
        self.admin.manageFees(fee: fee)
    }
}