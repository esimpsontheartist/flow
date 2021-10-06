
import NonFungibleToken from "./standard/NonFungibleToken.cdc"
import FractionalVault from "./FractionalVault.cdc"

pub contract Fraction: NonFungibleToken {
	
	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath
    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64

	//Count variable for the number of different set of fractions that have been minted (also used as an id)
	pub var count: UInt256

	//Total supply for a given fraction id
	priv var fractionSupply: {UInt256: UInt256}

	//Fraction id to vault id 
	pub var idToVault: {UInt64: UInt256}

    // Event that emitted when the NFT contract is initialized
    pub event ContractInitialized()

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

	//The resource that represents the
    pub resource NFT: NonFungibleToken.INFT {

		//Add this later
		//string private baseURI;
		/*
			function updateBaseUri(string calldata base) external onlyOwner {
			baseURI = base;
			}

			function uri(uint256 id)
				public
				view                
				override
				returns (string memory)
			{
				return
					bytes(baseURI).length > 0
						? string(abi.encodePacked(baseURI, id.toString()))
						: baseURI;
			}
		*/
		
		//global unique fraction ID
        pub let id: UInt64
		//Id to separate fractions by vault
		pub let vaultId: UInt256

        init(id: UInt64) {
            self.id = id
			self.vaultId = Fraction.count
        }

		destroy() {
			//remove from price because we are burning the NFT
			//change to a specific account where the VaultCollection will be stored
        	var vaultCollection = Fraction.account.getCapability(FractionalVault.VaultPublicPath).borrow<&{FractionalVault.VaultCollectionPublic}>() ?? panic("Could not borrow a reference to the account receiver")
			var vault = vaultCollection.borrowVault(id: Fraction.idToVault[self.id]!)
			vault!.removeFromPrice(1, vault!.userPrices[self.owner?.address!]!)
		}

    }

    //Standard NFT collectionPublic interface (should add a method to borrow a reference to the fraction?)
	pub resource interface CollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
	}

	// REVISIT THIS CODE AND ADD LOGIC FOR WHEN FRACTIONS ARE FROM A DIFFERENT VAULT
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

			//change to a specific account where the VaultCollection will be stored
        	var vaultCollection = Fraction.account.getCapability(FractionalVault.VaultPublicPath).borrow<&{FractionalVault.VaultCollectionPublic}>() ?? panic("Could not borrow a reference to the account receiver")
			var vault = vaultCollection.borrowVault(id: Fraction.idToVault[token.id]!)
			vault!.removeFromPrice(1, vault!.userPrices[self.owner?.address!]!)
			emit Withdraw(id: token.id, from: self.owner?.address)
			
			return <-token
		}

        // deposit takes a NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @Fraction.NFT

			let id: UInt64 = token.id

			// add the new token to the dictionary which removes the old one
			let oldToken <- self.ownedNFTs[id] <- token

			//change to a specific account where the VaultCollection will be stored
        	var vaultCollection = Fraction.account.getCapability(FractionalVault.VaultPublicPath).borrow<&{FractionalVault.VaultCollectionPublic}>() ?? panic("Could not borrow a reference to the account receiver")
			var vault = vaultCollection.borrowVault(id: Fraction.idToVault[id]!)
			vault!.addToPrice(1, vault!.userPrices[self.owner?.address!]!)

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

        destroy() {
			destroy self.ownedNFTs
		}

    }

    // public function that anyone can call to create a new empty collection
	pub fun createEmptyCollection(): @NonFungibleToken.Collection {
		return <- create Collection()
	}

	// function to mint a group of fractions corresponding to a vault
	//change to acces(acount), pub now for to avoid getting anoid by the linter
	pub fun mintFractions(amount: UInt256, vaultId: UInt256): @Collection {
		let newCollection <- create Collection()

		var i: UInt256 = 0 
		while i < amount {
			newCollection.deposit(token: <- create NFT(id: Fraction.totalSupply))
			self.idToVault[self.totalSupply] = vaultId
			self.totalSupply = self.totalSupply + 1
			i = i + 1
		}
		self.count = self.count + 1
		self.fractionSupply[self.count] = amount
		return <- newCollection
	}

	//function to burn a given amount of fractions 
	//change to acces(acount), pub now for to avoid getting anoid by the linter
	pub fun burnFractions(fractions: @Collection) {
		var amount = fractions.ownedNFTs.length
		self.fractionSupply[self.count] = self.fractionSupply[self.count]! - UInt256(amount)
		self.totalSupply = self.totalSupply - UInt64(amount)
		destroy fractions
	}

	//Get the total fraction suppkly for a given id (count)
	pub fun getFractionSupply(id: UInt256): UInt256 {
		return self.fractionSupply[id]!
	}

    init() {
		self.count = 0
        self.totalSupply = 0
		self.fractionSupply = {}
		self.idToVault = {}
		self.CollectionPublicPath = /public/fractionalCollection
		self.CollectionStoragePath = /storage/fractionalCollection

		self.account.save<@NonFungibleToken.Collection>(<- Fraction.createEmptyCollection(), to: Fraction.CollectionStoragePath)
		self.account.link<&{Fraction.CollectionPublic}>(Fraction.CollectionPublicPath, target: Fraction.CollectionStoragePath)

        emit ContractInitialized()	
    }
}