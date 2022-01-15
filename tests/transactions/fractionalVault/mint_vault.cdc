import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"
import CoreVault from "../../contracts/CoreVault.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

//Transaction to mint a new vault
transaction(
    vaultId: UInt64,
    maxSupply: UInt256
) {
    
    let vaultCollection: &CoreVault.VaultCollection
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {
        self.vaultCollection = account.borrow<&CoreVault.VaultCollection>(from: CoreVault.CollectionStoragePath)
        ?? panic("could not borrow a reference for the vault collection")
    }

    execute {
        //the contract will take care of depositing the minted fractionalVault into
        //the account's storage
        FractionalVault.mintVault(
            vault: <- self.vaultCollection.withdraw(withdrawID: vaultId), 
            bidVault: <- FlowToken.createEmptyVault(), 
            bidVaultType: Type<@FlowToken.Vault>(),
            vaultPath: /public/flowTokenReceiver,
            maxSupply: maxSupply
        )
    }
}


