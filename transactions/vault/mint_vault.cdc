import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import WrappedCollection from "../../contracts/WrappedCollection.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

//Transaction to mint a new vault
transaction(nftIds: [UInt64], fractionCurator: Address) {

    //An example NFT collection
    let collection: &ExampleNFT.Collection
    
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {
        self.collection = account.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) ?? panic("could not load collection")
    }

    execute {

        //Create the WrappedCollection to be deposited into the vault
        let collection <- WrappedCollection.createEmptyCollection()

        //withdraw the underlying
        for id in nftIds {
            let underlying <- self.collection.withdraw(withdrawID: id) as! @ExampleNFT.NFT
            let type = underlying.getType()
            let path = underlying.collectionPath
            let address = underlying.owner?.address!
            //wrap the underlying
            let wrapped <- WrappedCollection.wrap(nft: <- underlying, address: address, collectionPath: path, nftType: type)

            collection.depositWNFT(token: <- wrapped)
        }
        

        FractionalVault.mintVault(collection: <- collection, fractionCurator: fractionCurator)
    }
}


