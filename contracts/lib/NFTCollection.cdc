import NonFungibleToken from "../standard/NonFungibleToken.cdc"

// NFTCollection
//
// A general purpose generic collection contract for Flow NFTs
//
pub contract NFTCollection {

    pub let NFTCollectionStoragePath: StoragePath
	pub let NFTCollectionPublicPath: PublicPath
    //Event emmited when contract has been deployed
    pub event CollectionIntialized()

    // Event that is emitted when a token is withdrawn,
    // indicating the owner of the collection that it was withdrawn from.
    //
    // If the collection is not in an account's storage, `from` will be `nil`.
    //
    pub event Withdraw(id: UInt64, from: Address?)

    // Event that emitted when a token is deposited to a collection.
    //
    // It indicates the owner of the collection that it was deposited to.
    //
    pub event Deposit(id: UInt64, to: Address?)

    //Check NFTStoreFront.cdc in order to add struct for data keeping

    //interface that can also borrowArt as the correct type
	pub resource interface NFTCollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
	}

    pub resource Collection: NFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.uuid, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
         
            let id: UInt64 = token.uuid

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NFTCollection.Collection {
        return <- create Collection()
    }


    init(){
        self.NFTCollectionPublicPath = /public/fractionalCollection
		self.NFTCollectionStoragePath = /storage/fractionalCollection

        self.account.save<@NFTCollection.Collection>(<- NFTCollection.createEmptyCollection(), to: NFTCollection.NFTCollectionStoragePath)
		self.account.link<&{NFTCollection.NFTCollectionPublic}>(NFTCollection.NFTCollectionPublicPath, target: NFTCollection.NFTCollectionStoragePath)

        emit CollectionIntialized()
    }
}