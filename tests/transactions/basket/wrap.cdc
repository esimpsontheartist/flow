import Basket from "../../contracts/Basket.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"

transaction(
    nftIds: [UInt64]
) { 
    //An example NFT collection
    let collection: &ExampleNFT.Collection
    
    //Wrapped collection to receive the wrapped NFTs
    let basketCap: Capability<&{Basket.CollectionPublic}>

    prepare(account: AuthAccount) {
        
        self.collection = account.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) 
        ?? panic("could not load collection")

        self.basketCap = account.getCapability<&{Basket.CollectionPublic}>(Basket.CollectionPublicPath)
    }

    execute {

        let basket = self.basketCap.borrow() ?? panic("could not borrow wrapped collection")

        for id in nftIds {
            let ref = self.collection.borrowNFT(id: id)
            let underlying <- self.collection.withdraw(withdrawID: id) as! @ExampleNFT.NFT
            let type = underlying.getType()
            let path = underlying.collectionPath
            let address = ref.owner?.address!
            let metadata: {String: AnyStruct} = {"uri": "https://rinkeby-api.fractional.art/fractions/10"}
            //wrap the underlying
            let wrapped <- Basket.wrap(nft: <- underlying, address: address, collectionPath: path, nftType: type, metadata: metadata)

            basket.deposit(token: <- wrapped)
        }

    }

}