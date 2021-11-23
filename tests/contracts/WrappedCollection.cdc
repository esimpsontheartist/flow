import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract WrappedCollection: NonFungibleToken {

    
	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath

    //Event emmited when contract has been deployed
    pub event CollectionIntialized()

    pub var totalSupply: UInt64

    // Event that emitted when the NFT contract is initialized
    pub event ContractInitialized()

    pub event Withdraw(id: UInt64, from: Address?)

    pub event Deposit(id: UInt64, to: Address?)

	pub resource interface WrappedNFT {
       pub fun getAddress(): Address
       pub fun getUnderlyingCollectionPath(): PublicPath
       pub fun nestedType(): Type
       pub fun borrowNFT(): &NonFungibleToken.NFT
    }

    // An NFT wrapped with useful information (by @briandilley)
    pub resource NFT : WrappedNFT, NonFungibleToken.INFT {
        pub let id: UInt64
        access(contract) var nft: @NonFungibleToken.NFT?
        access(self) let address: Address
        access(self) let underlyingCollectionPath: PublicPath
        access(self) let nftType: Type

        init(
            nft: @NonFungibleToken.NFT,
            address: Address,
            underlyingCollectionPath: PublicPath,
            nftType: Type
        ) {
            self.id = nft.uuid
            self.nft <- nft
            self.address = address
            self.underlyingCollectionPath = underlyingCollectionPath
            self.nftType = nftType
        }

        pub fun getAddress(): Address {
            return self.address
        }

        pub fun getUnderlyingCollectionPath(): PublicPath {
            return self.underlyingCollectionPath
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
    pub fun wrap(nft: @NonFungibleToken.NFT, address: Address, collectionPath: PublicPath, nftType: Type ): @WrappedCollection.NFT {
        return <- create NFT(nft: <- nft, address: address, underlyingCollectionPath: collectionPath, nftType: nftType)
    }
    

    //interface that can also borrowArt as the correct type
	pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowWNFT(id: UInt64): &{WrappedCollection.WrappedNFT}?
	}

     pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        
		// dictionary of NFT conforming tokens
		// NFT is a resource type with an `UInt64` ID field
		pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

		init () {
			self.ownedNFTs <- {}
		}

        // withdraw removes an NFT from the collection and moves it to the caller
		pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
			//remove the WNFT from the ownedNFTs dictionary
            let wnft <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: wnft.uuid, from: self.owner?.address)

            return <- wnft
		}

        // deposit takes a NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @WrappedCollection.NFT
            
            let id: UInt64 = token.id
            //need to create the WNFT
            
            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token
            
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
		}

		// getIDs returns an array of the IDs that are in the collection
		pub fun getIDs(): [UInt64] {
			return self.ownedNFTs.keys
		}

        // Returns a borrowed reference to an NFT in the collection
        // so that the caller can read data and call methods from it
        // borrowNFT gets a reference to an NFT in the collection
		// so that the caller can read its metadata and call its methods
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
			return &self.ownedNFTs[id] as &NonFungibleToken.NFT
		}

        // borrowWNFT gets a reference to a WNFT in the collection
        // so that the caller can read its metadata and call its methods, etc
        pub fun borrowWNFT(id: UInt64): &{WrappedCollection.WrappedNFT}? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &WrappedCollection.NFT
            } else {
                return nil
            }
            
        }



        destroy() {
			destroy self.ownedNFTs
		}

    }

    // public function that anyone can call to create a new empty collection
	pub fun createEmptyCollection(): @NonFungibleToken.Collection {
		return <- create Collection()
	} 

    init() {
        self.totalSupply = 0
        self.CollectionPublicPath =  /public/wrappedCollection
		self.CollectionStoragePath = /storage/wrappedCollection

        emit CollectionIntialized()
    }
}