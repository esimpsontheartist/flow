import FractionalVault from "../../contracts/FractionalVault.cdc"
import Fraction from "../../contracts/Fraction.cdc"

//Transaction to mint a new vault
transaction(vaultId: UInt256) {

    let curator: Capability<&{Fraction.CollectionPublic}>
    prepare(account: AuthAccount) {
        self.curator = account.getCapability<&{Fraction.CollectionPublic}>(Fraction.CollectionPublicPath)
    }
    execute {
       FractionalVault.mintVaultFractions(vaultId: vaultId, curator: self.curator)
    }
}