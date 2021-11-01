import FractionalVault from "../../contracts/FractionalVault.cdc"

//Transaction to mint a new vault
transaction(vaultId: UInt256) {

    prepare(account: AuthAccount) {
        //do nothing
    }
    execute {
       FractionalVault.mintVaultFractions(vaultId: vaultId)
    }
}