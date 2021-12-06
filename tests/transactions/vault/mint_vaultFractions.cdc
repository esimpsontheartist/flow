import FractionalVault from "../../contracts/FractionalVault.cdc"
import Fraction from "../../contracts/Fraction.cdc"

//Transaction to mint a new vault
transaction(vaultId: UInt256) {

    let curator: Capability<&Fraction.Collection>
    prepare(account: AuthAccount) {
        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }
    execute {
       FractionalVault.mintVaultFractions(vaultId: vaultId, curator: self.curator)
    }
}