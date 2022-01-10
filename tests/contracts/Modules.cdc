import NonFungibleToken from "./NonFungibleToken.cdc"
import Fraction from "./Fraction.cdc"
pub contract Modules {

    /**
    * Module Interfaces
    *
    * These interfaces allow Fractional Vault modules to implement them.
    * This allows other contracts/resources to make new resources or functions
    * with the only assumption being that a given modules resoucre conforms to 
    * the interface.
    * 
    * For example:
    * Module A may allow a CoreVault that get's deposited into it to add the ability
    * for the underlying NFT to be won through an auction, while Module B may allow 
    * a CoreVault to put the underlying NFT up for a lottery. Neither modules makes
    * a specific change to the way in which fractions get minted, and thus can implement
    * SimpleMinter interface.
    *
    * Now assume that we have a Contract called FixedSale, which takes in resources
    * based on the type "{SimpleMinter}". This allows vaults using module A or B to
    * leverage FixedSale to mint fractions on demand and set a price for these.
    *
    * If a third module, Module C, does not implement the "SimpleMinter" interface,
    * then it cannot used the FixedSale contract. 
    *
    * The same logic can be applied for other aspects of the vault.
    */

    pub resource interface CappedMinter {
        pub let maxSupply: UInt256
        pub fun mint(amount: UInt256): @Fraction.Collection
    }

    pub resource interface CappedMinterCollection { 
        pub fun getIDs(): [UInt64]
        pub fun borrowMinter(id: UInt64): &{Modules.CappedMinter}?
    }
}