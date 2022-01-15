import Fraction from "../../contracts/Fraction.cdc"

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