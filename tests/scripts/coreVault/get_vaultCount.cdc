import CoreVault from "../../contracts/CoreVault.cdc"

// A script to return the number of vaults that have been created
// Same as "totalSupply" of vaults

pub fun main(): UInt256{
    return CoreVault.getVaultCount()
}