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
        let vaultAddress = FractionalVault.vaultAddress
        self.vaultCollection = getAccount(vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
            ?? panic("Could not borrow a reference to the Fractional Vault Collection")
        self.collection = account.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) ?? panic("could not load collection")
    }

    execute {
        //withdraw the underlying
        let underlying <- self.collection.withdraw(withdrawID: nftId) as! @ExampleNFT.NFT
        let type = underlying.getType()
        let path = underlying.collectionPath
        let address = underlying.owner?.address!
        //wrap the underlying
        let wrapped <- WrappedCollection.wrap(nft: <- underlying, address: address, collectionPath: path, nftType: type)

        //Create the WrappedCollection to be deposited into the vault
        let collection <- WrappedCollection.createEmptyCollection()
        collection.depositWNFT(token: <- wrapped)

        //deposit the vault
        self.vaultCollection.depositVault(vault: <- FractionalVault.mint(collection: <- collection))
    }
}


