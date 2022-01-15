import Fraction from "../../contracts/Fraction.cdc"

transaction(uri: String) {
    let administrator: &Fraction.Administrator
    prepare(signer: AuthAccount) {
        self.administrator = signer.borrow<&Fraction.Administrator>(from: Fraction.AdministratorStoragePath)
        ?? panic("could not borrow administrator resource from this account")
    }

    execute {
        self.administrator.setUriBase(uri)
    }
}