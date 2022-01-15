import Fraction from "../../contracts/Fraction.cdc"

//Get the number of fractions inside of a collection
//for a given index
pub fun main(address: Address, index: Int): Int {
    let burner = getAccount(address).getCapability<&Fraction.BurnerCollection>(Fraction.BurnerPublicPath).borrow()
    ?? panic("could not get a reference to the burner for the given address")

    return burner.amountAt(index)
}