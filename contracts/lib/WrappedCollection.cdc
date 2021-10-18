import NonFungibleToken from "../standard/NonFungibleToken.cdc"

// NFTCollection
//
// A general purpose generic collection contract for Flow NFTs
//
pub contract WrappedCollection {

    pub let WrappedCollectionStoragePath: StoragePath
	pub let WrappedCollectionPublicPath: PublicPath
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

    pub resource interface WrappedNFT {
       pub fun getAddress(): Address
       pub fun getCollectionPath(): PublicPath
       pub fun nestedType(): Type
       pub fun borrowNFT(): &NonFungibleToken.NFT
    }

    // An NFT wrapped with useful information (by @briandilley)
    pub resource WNFT : WrappedNFT {
        access(contract) var nft: @NonFungibleToken.NFT?
        access(self) let address: Address
        access(self) let collectionPath: PublicPath
        access(self) let nftType: Type

        init(
            nft: @NonFungibleToken.NFT,
            address: Address,
            collectionPath: PublicPath,
            nftType: Type
        ) {
            self.nft <- nft
            self.address = address
            self.collectionPath = collectionPath
            self.nftType = nftType
        }

        pub fun getAddress(): Address {
            return self.address
        }

        pub fun getCollectionPath(): PublicPath {
            return self.collectionPath
        }

        pub fun nestedType(): Type {
            return self.nftType
        }

        pub fun borrowNFT(): &NonFungibleToken.NFT {
            pre {
                self.nft != nil: "Wrapped NFT is nil"
            }
            let optionalNft <- self.nft <- nil
            let nft <- optionalNft!!
            let ret = &nft as &NonFungibleToken.NFT
            self.nft <-! nft
            return ret!!
        }

        pub fun unwrap(): @NonFungibleToken.NFT {
            let nft <- self.nft <- nil
            return <- nft!
        }

        destroy() {
            pre {
                self.nft == nil: "Wrapped NFT is not nil"
            }
            destroy self.nft
        }
    }

    // a function to wrap an NFT
    pub fun wrap(nft: @NonFungibleToken.NFT, address: Address, collectionPath: PublicPath, nftType: Type ): @WrappedCollection.WNFT {
        return <- create WNFT(nft: <- nft, address: address, collectionPath: collectionPath, nftType: nftType)
    }

    //interface that can also borrowArt as the correct type
	pub resource interface WrappedCollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowWNFT(id: UInt64): &WrappedCollection.WNFT
	}

    pub resource Collection: WrappedCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: WNFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an WNFT from the collection, unwraps it, and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            //remove the WNFT from the ownedNFTs dictionary
            let wnft <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            let nft <- wnft.unwrap()

            emit Withdraw(id: nft.uuid, from: self.owner?.address)
            destroy wnft
            return <- nft
        }

        // deposit takes a NFT conforming to WNFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @WrappedCollection.WNFT
            //need to create the WNFT
            let id: UInt64 = token.uuid

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun depositWNFT(token: @WrappedCollection.WNFT) {
            //need to create the WNFT
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
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            let borrowed = &self.ownedNFTs[id] as &WNFT
            return borrowed.borrowNFT()
        }

        // borrowWNFT gets a reference to a WNFT in the collection
        // so that the caller can read its metadata and call its methods, etc
        pub fun borrowWNFT(id: UInt64): &WrappedCollection.WNFT {
            let borrowed = &self.ownedNFTs[id] as &WNFT
            return borrowed
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @WrappedCollection.Collection {
        return <- create Collection()
    }


    init(){
        self.WrappedCollectionPublicPath = /public/fractionalCollection
		self.WrappedCollectionStoragePath = /storage/fractionalCollection

        self.account.save<@WrappedCollection.Collection>(<- WrappedCollection.createEmptyCollection(), to: WrappedCollection.WrappedCollectionStoragePath)
		self.account.link<&{WrappedCollection.WrappedCollectionPublic}>(WrappedCollection.WrappedCollectionPublicPath, target: WrappedCollection.WrappedCollectionStoragePath)

        emit CollectionIntialized()
    }
}