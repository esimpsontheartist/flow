import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import ExampleNFT from "../../contracts/lib/ExampleNFT.cdc"

//Transaction to mint a new vault

transaction(recipient: Address, nftId: UInt64) {
    
    // local variable for storing the collection reference
    let collection: &{ExampleNFT.CollectionPublic}

    prepare(account: AuthAccount) {
        self.collection = getAccount(recipient).getCapability<&{ExampleNFT.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
            .borrow()
            ?? panic("Could not borrow a collection reference")
    }

    execute {
        
        self.collection.deposit(token: <- ExampleNFT.mint())

        log("Minted an example NFT to the Account's collection")
    }

}

