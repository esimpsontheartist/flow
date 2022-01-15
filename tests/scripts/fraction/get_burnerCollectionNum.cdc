import Fraction from "../../contracts/Fraction.cdc"

/**
    Number of collections held in the burner collection
    Makes no assumptions as to how collections are ordered
    or to what vault the belong to, simply tells us how
    many collections have yet to be burned.
    The result is the same as getting the length of the
    array of collections
*/
pub fun main(address: Address): Int {
    let burner = getAccount(address).getCapability<&Fraction.BurnerCollection>(Fraction.BurnerPublicPath).borrow()
    ?? panic("could not get a reference to the burner for the given address")

    return burner.numOfCollections()
}