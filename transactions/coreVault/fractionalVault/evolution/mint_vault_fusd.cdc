import FUSD from "../../../../contracts/core/FUSD.cdc"
import CoreVault from "../../../../contracts/CoreVault.cdc"
import FractionalVault from "../../../../contracts/FractionalVault.cdc"
import Fraction from "../../../../contracts/Fraction.cdc"
import Evolution from "../../../../contracts/third-party/Evolution.cdc"

transaction(
    nftIds: [UInt64],
    name: String,
    description: String,
    maxSupply: UInt256
) {
    let vaultCollection: &CoreVault.VaultCollection
    //An example NFT collection
    let collection: &Evolution.Collection
    
    let curator: Capability<&{Fraction.BulkCollectionPublic}>
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {

        self.vaultCollection = account.borrow<&CoreVault.VaultCollection>(from: CoreVault.CollectionStoragePath)
        ?? panic("could not borrow a reference to the account's vault collection")
        
        self.collection = account.borrow<&Evolution.Collection>(from: /storage/f4264ac8f3256818_Evolution_Collection) 
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
            underlyingType: Type<@Evolution.Collection>(),
            name: name,
            description: description
        )

        FractionalVault.mintVault(
            vault: <- vault, 
            bidVault: <- FUSD.createEmptyVault(), 
            bidVaultType: Type<@FUSD.Vault>(),
            vaultPath: /public/fusdReceiver,
            maxSupply: maxSupply
        )


    }
}