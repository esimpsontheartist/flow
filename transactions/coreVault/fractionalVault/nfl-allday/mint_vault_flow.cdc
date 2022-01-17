import FlowToken from "../../../../contracts/core/FlowToken.cdc"
import CoreVault from "../../../../contracts/CoreVault.cdc"
import FractionalVault from "../../../../contracts/FractionalVault.cdc"
import Fraction from "../../../../contracts/Fraction.cdc"
import AllDay from "../../../../contracts/third-party/AllDay.cdc"

transaction(
    nftIds: [UInt64],
    name: String,
    description: String,
    maxSupply: UInt256
) {
    let vaultCollection: &CoreVault.VaultCollection
    //An example NFT collection
    let collection: &AllDay.Collection
    
    let curator: Capability<&{Fraction.BulkCollectionPublic}>
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {

        self.vaultCollection = account.borrow<&CoreVault.VaultCollection>(from: CoreVault.CollectionStoragePath)
        ?? panic("could not borrow a reference to the account's vault collection")
        
        self.collection = account.borrow<&AllDay.Collection>(from: AllDay.CollectionStoragePath) 
        ?? panic("could not borrow a reference to the topshot collection")

        self.curator = account.getCapability<&{Fraction.BulkCollectionPublic}>(Fraction.CollectionPublicPath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {

        let allDayCollection <- AllDay.createEmptyCollection()

        for id in nftIds {
            allDayCollection.deposit(token: <- self.collection.withdraw(withdrawID: id))
        }
        
        let vault <- CoreVault.mintVault(
            curator: self.curator,
            underlying: <- allDayCollection,
            underlyingType: Type<@AllDay.Collection>(),
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