import NonFungibleToken from "../standard/NonFungibleToken.cdc"

// A simple NFT contract to be used in testing

pub contract ExampleNFT: NonFungibleToken {

    
	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath

    pub var totalSupply: UInt64

    // Event that emitted when the NFT contract is initialized
    pub event ContractInitialized()

    pub event Withdraw(id: UInt64, from: Address?)

    pub event Deposit(id: UInt64, to: Address?)

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
		pub let collectionPath: PublicPath
        init() {
            self.id = ExampleNFT.totalSupply
			self.collectionPath = ExampleNFT.CollectionPublicPath
            ExampleNFT.totalSupply = ExampleNFT.totalSupply + 1
        }
    }

    pub resource interface CollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
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
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

			emit Withdraw(id: token.id, from: self.owner?.address)
			
			return <-token
		}

        // deposit takes a NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @ExampleNFT.NFT

			let id: UInt64 = token.id

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

		//returns the number of fractions in a collection
		pub fun balance(): UInt256 {
			return UInt256(self.ownedNFTs.keys.length)
		}

        destroy() {
			destroy self.ownedNFTs
		}

    }

    // public function that anyone can call to create a new empty collection
	pub fun createEmptyCollection(): @NonFungibleToken.Collection {
		return <- create Collection()
	}

	pub fun mint(): @NonFungibleToken.NFT {
		return <- create NFT()
	}

    init() {
        self.totalSupply = 0
        self.CollectionPublicPath = /public/exampleCollection
		self.CollectionStoragePath = /storage/exampleCollection
    }
}