import FlowToken from "../../../../contracts/core/FlowToken.cdc"
import CoreVault from "../../../../contracts/CoreVault.cdc"
import FractionalVault from "../../../../contracts/FractionalVault.cdc"
import Fraction from "../../../../contracts/Fraction.cdc"
import MotoGPCard from "../../../../contracts/third-party/MotoGPCard.cdc"

transaction(
    nftIds: [UInt64],
    name: String,
    description: String,
    maxSupply: UInt256
) {
    let vaultCollection: &CoreVault.VaultCollection
    //An example NFT collection
    let collection: &MotoGPCard.Collection
    
    let curator: Capability<&{Fraction.BulkCollectionPublic}>
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {

        self.vaultCollection = account.borrow<&CoreVault.VaultCollection>(from: CoreVault.CollectionStoragePath)
        ?? panic("could not borrow a reference to the account's vault collection")
        
        self.collection = account.borrow<&MotoGPCard.Collection>(from: /storage/motogpCardCollection) 
        ?? panic("could not borrow a reference to the MotoGP collection")

        self.curator = account.getCapability<&{Fraction.BulkCollectionPublic}>(Fraction.CollectionPublicPath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {

        let motoGPCollection <- MotoGPCard.createEmptyCollection()

        for id in nftIds {
            motoGPCollection.deposit(token: <- self.collection.withdraw(withdrawID: id))
        }
        
        let vault <- CoreVault.mintVault(
            curator: self.curator,
            underlying: <- motoGPCollection,
            underlyingType: Type<@MotoGPCard.Collection>(),
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