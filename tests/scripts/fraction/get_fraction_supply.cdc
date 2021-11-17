import Fraction from "../../contracts/Fraction.cdc"


// This scripts returns the number of Fractions currently in existence for a given vaultId

pub fun main(vaultId: UInt256): UInt256 {    
    return Fraction.getFractionSupply(vaultId: vaultId)
}