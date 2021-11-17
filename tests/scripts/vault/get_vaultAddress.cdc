import FractionalVault from "../../contracts/FractionalVault.cdc"

// A script to return the address where the vaults are stored

pub fun main(): Address{
    return FractionalVault.vaultAddress
}