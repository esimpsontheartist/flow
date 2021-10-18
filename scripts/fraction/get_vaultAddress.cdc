import Fraction from "../../contracts/Fraction.cdc"


// This scripts returns the totalSupply of all Fractions currently in existance

pub fun main(): Address {    
    return Fraction.vaultAddress
}