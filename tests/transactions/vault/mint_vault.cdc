import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"
import WrappedCollection from "../../contracts/WrappedCollection.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

//Transaction to mint a new vault
transaction(nftIds: [UInt64], fractionCurator: Address) {

    //An example NFT collection
    let collection: &ExampleNFT.Collection
    
    let curator: Capability<&{Fraction.CollectionPublic}>
    //The user authorizes borrowing the transaction to borrow the collection
    prepare(account: AuthAccount) {
        self.collection = account.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) 
        ?? panic("could not load collection")

        self.curator = account.getCapability<&{Fraction.CollectionPublic}>(Fraction.CollectionPublicPath)
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

            collection.deposit(token: <- wrapped)
        }
        

        FractionalVault.mintVault(
            collection: <- collection, 
            collectionType: Type<@WrappedCollection.Collection>(),
            bidVault: <- FlowToken.createEmptyVault(),
            bidVaultType: Type<@FlowToken.Vault>(),
            curator: self.curator
        )
    }
}


