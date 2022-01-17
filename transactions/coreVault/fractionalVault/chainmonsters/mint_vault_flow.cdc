import FlowToken from "../../../../contracts/core/FlowToken.cdc"
import CoreVault from "../../../../contracts/CoreVault.cdc"
import FractionalVault from "../../../../contracts/FractionalVault.cdc"
import Fraction from "../../../../contracts/Fraction.cdc"
import ChainmonstersRewards from "../../../../contracts/third-party/ChainmonstersRewards.cdc"

transaction(
    nftIds: [UInt64],
    name: String,
    description: String,
    maxSupply: UInt256
) {
    let vaultCollection: &CoreVault.VaultCollection
    //An example NFT collection
    let collection: &ChainmonstersRewards.Collection
    
    let curator: Capability<&{Fraction.BulkCollectionPublic}>
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {

        self.vaultCollection = account.borrow<&CoreVault.VaultCollection>(from: CoreVault.CollectionStoragePath)
        ?? panic("could not borrow a reference to the account's vault collection")
        
        self.collection = account.borrow<&ChainmonstersRewards.Collection>(from: /storage/ChainmonstersRewardCollection) 
        ?? panic("could not borrow a reference to the MotoGP collection")

        self.curator = account.getCapability<&{Fraction.BulkCollectionPublic}>(Fraction.CollectionPublicPath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        
        //Create the WrappedCollection to be deposited into the vault
        let basket <- self.collection.batchWithdraw(ids: nftIds)

        
        let vault <- CoreVault.mintVault(
            curator: self.curator,
            underlying: <- basket,
            underlyingType: Type<@ChainmonstersRewards.Collection>(),
            name: name,
            description: description
        )

        FractionalVault.mintVault(
            vault: <- vault, 
            bidVault: <- FlowToken.createEmptyVault(), 
            bidVaultType: Type<@FlowToken.Vault>(),
            vaultPath: /public/flowTokenReceiver,
            maxSupply: maxSupply
        )


    }
}