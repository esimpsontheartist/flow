import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import ExampleNFT from "../../contracts/ExampleNFT.cdc"

//Transaction to mint a new ExampleNFt

transaction(recipient: Address) {
    
    // local variable for storing the collection reference
    let collection: &{ExampleNFT.CollectionPublic}

    prepare(account: AuthAccount) {
        self.collection = getAccount(recipient).getCapability<&{ExampleNFT.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
            .borrow()
            ?? panic("Could not borrow a collection reference")
    }

    execute {
        
        self.collection.deposit(token: <- ExampleNFT.mint())

    }

}

