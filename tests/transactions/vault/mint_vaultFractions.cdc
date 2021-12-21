import FractionalVault from "../../contracts/FractionalVault.cdc"
import Fraction from "../../contracts/Fraction.cdc"

//Transaction to mint a new vault
transaction(vaultId: UInt256) {

    let curator: Capability<&Fraction.BulkCollection>
    prepare(account: AuthAccount) {
        self.curator = account.getCapability<&Fraction.BulkCollection>(Fraction.CollectionPrivatePath)
    }
    execute {
       FractionalVault.mintVaultFractions(vaultId: vaultId, curator: self.curator)
    }
}