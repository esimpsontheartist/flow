import NonFungibleToken from "../../contracts/core/NonFungibleToken.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"

//Transaction that configures an account to hold an example NFT

transaction() {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) == nil {

            // create a new empty collection
            let collection <- ExampleNFT.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: ExampleNFT.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&ExampleNFT.Collection{NonFungibleToken.CollectionPublic, ExampleNFT.CollectionPublic}>(ExampleNFT.CollectionPublicPath, target: ExampleNFT.CollectionStoragePath)
        }
    }
}
