import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import WrappedCollection from "../../contracts/WrappedCollection.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

//Transaction to mint a new vault
transaction(nftId: UInt64, fractionRecipient: Address) {

    //An example NFT collection
    let collection: &ExampleNFT.Collection
    
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {
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

        FractionalVault.mintVault(collection: <- collection, fractionRecipient: fractionRecipient)
    }
}


