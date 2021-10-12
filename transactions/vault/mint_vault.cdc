import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import WrappedCollection from "../../contracts/lib/WrappedCollection.cdc"
import ExampleNFT from "../../contracts/lib/ExampleNFT.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

//Transaction to mint a new vault

transaction(nftId: UInt64) {

    // Reference to the vault account
    let vaultCollection: &{FractionalVault.VaultCollectionPublic}
    
    //An example NFT collection
    let collection: &ExampleNFT.Collection
    
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {
        self.vaultCollection = account.borrow<&{FractionalVault.VaultCollectionPublic}>(from: FractionalVault.VaultStoragePath) ?? panic("could not load the account's vaults")
        self.collection = account.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) ?? panic("could not load collection")
    }

    execute {
        //withdraw the underlying
        let underlying <- self.collection.withdraw(withdrawID: nftId)

        //Create the WrappedCollection to be deposited into the vault
        let collection <- WrappedCollection.createEmptyCollection()
        collection.deposit(token: <- underlying)

        //deposit the vault
        self.vaultCollection.depositVault(vault: <- FractionalVault.mint(collection: <- collection))
    }
}


