import WrappedCollection from "../../contracts/WrappedCollection.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

transaction(
    nftIds: [UInt64]
) { 
    //An example NFT collection
    let collection: &ExampleNFT.Collection
    
    //Wrapped collection to receive the wrapped NFTs
    let wrappedCollectionCap: Capability<&{WrappedCollection.CollectionPublic}>

    prepare(account: AuthAccount) {
        
        self.collection = account.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) 
        ?? panic("could not load collection")

        self.wrappedCollectionCap = account.getCapability<&{WrappedCollection.CollectionPublic}>(WrappedCollection.CollectionPublicPath)
    }

    execute {

        let wrappedCollection = self.wrappedCollectionCap.borrow() ?? panic("could not borrow wrapped collection")

        for id in nftIds {
            let underlying <- self.collection.withdraw(withdrawID: id) as! @ExampleNFT.NFT
            let type = underlying.getType()
            let path = underlying.collectionPath
            let address = underlying.owner?.address!
            //wrap the underlying
            let wrapped <- WrappedCollection.wrap(nft: <- underlying, address: address, collectionPath: path, nftType: type)

            wrappedCollection.deposit(token: <- wrapped)
        }

    }

}