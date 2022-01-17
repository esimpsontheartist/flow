import Fraction from "../../contracts/Fraction.cdc"

// The correct address for this transaction is that of the account
// that has the FractionalVault contract deployed
transaction(address: Address, amount: Int) {

    let burner: &Fraction.BurnerCollection

    prepare(signer: AuthAccount) {
        self.burner =  getAccount(address).getCapability<&Fraction.BurnerCollection>(Fraction.BurnerPublicPath).borrow()
        ?? panic("could not get a reference to the burner for the given address")
    }

    execute {
        self.burner.burnFractions(amount)
    }

}