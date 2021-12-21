import NonFungibleToken from "./NonFungibleToken.cdc"
import TypedMetadata from "./TypedMetadata.cdc"
import EnumerableSet from "./EnumerableSet.cdc"
import PriceBook from "./PriceBook.cdc"

pub contract Fraction: NonFungibleToken {

	// PROHIBBIT CONTRACT OWNER FROM MINTING
	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath
	pub let CollectionPrivatePath: PrivatePath
	pub let AdministratorStoragePath: StoragePath

    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64
	// The API endpoint for Fraction metadata
	access(account) var baseURI: String
	//A function to set the URI endpoint
	access(account) fun setUriBase(_ uri: String) {
		self.baseURI = uri
	}
	//Total supply for a given fraction id
	access(account) let fractionSupply: {UInt64: UInt256}

	//Total supply that can be minted for a vault
	access(account) let maxVaultSupply: {UInt64: UInt256}
	//Fraction id to vault id 
	access(account) let idToVault: {UInt64: UInt64}

    // Event that emitted when the NFT contract is initialized
    pub event ContractInitialized()

    // Event that is emitted when a token is withdrawn,
    // indicating the owner of the collection that it was withdrawn from.
    //
    // If the collection is not in an account's storage, `from` will be `nil`.
    //
    pub event Withdraw(id: UInt64, from: Address?)

	// Event that is emitted when a collection is withdrawn from the FractionCollection,
    // indicating the owner of the collection that it was withdrawn from.
    //
    // If the collection is not in an account's storage, `from` will be `nil`.
    //
    pub event WithdrawCollection(id: UInt64, from: Address?)

    // Event that emitted when a token is deposited to a collection.
    //
    // It indicates the owner of the collection that it was deposited to.
    //
    pub event Deposit(id: UInt64, to: Address?)

	// Event thats emitted when a collection is deposited to a fraction collection.
    //
    // It indicates the owner of the collection that it was deposited to.
    //
    pub event DepositCollection(id: UInt64, to: Address?)
	
	pub struct FractionData {
		pub let vaultId: UInt64
		pub let uri: String
		pub let curator: Address
		pub let name: String
		pub let description: String

        init(
			vaultId: UInt64,
			uri: String,
			curator: Address,
			name: String,
			description: String
		) {
			self.vaultId = vaultId
			self.uri = uri
			self.curator = curator
			self.name = name
			self.description = description
        }
	}

	access(account) let vaultToFractionData: {UInt64: FractionData}

	pub event MintFractions(ids: [UInt64], metadata: FractionData)
	
	//The resource that represents the Fraction NFT
    pub resource NFT: NonFungibleToken.INFT, TypedMetadata.ViewResolver {

		//global unique fraction ID
        pub let id: UInt64
		//Id to separate fractions by vault
		pub let vaultId: UInt64
		//Uri used to display data for a fraction
		pub let uri: String
		//Curator for the fraction
		pub let curator: Address
		//Name given to the vault/fractions
		pub let name: String
		//Description given for the vault/fractions
		pub let description: String

        init(
			id: UInt64, 
			vaultId: UInt64,
		) {
            self.id = id
			self.vaultId = vaultId
			self.curator = Fraction.vaultToFractionData[self.vaultId]!.curator
			self.name = Fraction.vaultToFractionData[self.vaultId]!.name
			self.description = Fraction.vaultToFractionData[self.vaultId]!.description
			self.uri = Fraction.vaultToFractionData[self.vaultId]!.uri
		}

		//A function to return the Type of views supported by the NFT
		pub fun getViews(): [Type] {
			return [
				Type<String>(),
				Type<TypedMetadata.Display>()
			]
		}

		//A function to return the Struct for a given Type of view supported by the NFT
		pub fun resolveView(_ type: Type): AnyStruct {

			if type == Type<String>() {
				return self.name.concat(" ").concat(" by: ").concat(self.curator.toString()).concat("vaultId: ").concat(self.vaultId.toString()).concat("fractionId: ").concat(self.id.toString())
			}

			if type == Type<TypedMetadata.Display>() {
				return TypedMetadata.Display(name: self.name, thumbnail: self.uri, description: self.description, source: "fractional")
			}
			
			//return nil if the typed passed is not supported
			return nil
		}

		destroy() {
			let priceBook = PriceBook.fractionPrices[self.vaultId] ?? {}
			if priceBook.length > 0 && priceBook[self.id] != nil{
				PriceBook.removeFromPrice(self.vaultId, 1, priceBook[self.id]!)
			}
			//remove from price because we are burning the NFT
			Fraction.fractionSupply[self.vaultId] = Fraction.fractionSupply[self.vaultId]! - 1
			// update PriceBook
			PriceBook.removeFromSupply(self.vaultId, 1)
		}

    }

    //Standard NFT collectionPublic interface (should add a method to borrow a reference to the fraction?)
	pub resource interface CollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
		pub fun borrowFraction(id: UInt64): &Fraction.NFT?
	}

	//Interface for the Fractional Vault 
	//Prevents fractions from being deposited to a vault through the `deposit()` function
	pub resource interface CollectionRestricted {
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
		pub fun borrowFraction(id: UInt64): &Fraction.NFT?
	}
	//Stored by other contracts or a temporary means of moving multiple fractions
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic, CollectionRestricted {
        
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
			let token <- token as! @Fraction.NFT

			let id: UInt64 = token.id
			let vaultId: UInt64 = token.vaultId
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

		// Returns a borrowed reference to a Fraction
        // so that the caller can read data and call methods from it
		pub fun borrowFraction(id: UInt64): &Fraction.NFT? {
			if self.ownedNFTs[id] != nil {
				let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
				return ref as! &Fraction.NFT
			} else {
				return nil
			}
		}

        destroy() {
			destroy self.ownedNFTs
		}

    }

	//Functions for public references to the Bulk Collection
	pub resource interface BulkCollectionPublic {
		pub fun deposit(token: @NonFungibleToken.NFT)
		pub fun getIDs(): [UInt64]
		pub fun getVaultIds(): [UInt64]
		pub fun getIDsByVault(vaultId: UInt64): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
		pub fun borrowFraction(id: UInt64): &Fraction.NFT?
	}

	//Stored by users to manager their fractions
	pub resource BulkCollection: NonFungibleToken.CollectionPublic, BulkCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver {

		// a dictionary of Collections
		pub var ownedCollections: @{UInt64: Collection}

		priv let fractionToVault: {UInt64: UInt64}
		priv let vaultToFractions: {UInt64: EnumerableSet.UInt64Set}

		init() {
			self.fractionToVault = {}
			self.vaultToFractions = {}
			self.ownedCollections <- {}
		}

		pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
			//Find the collection from where a token should be withdrawn
			let vaultId = self.fractionToVault[withdrawID] ?? panic("withdraw:no fractions stored for this vaultId")

			// Withdraw the Fraction NFT
			let token <- self.ownedCollections[vaultId]?.withdraw(withdrawID: withdrawID)!

			//remove from the mappings
			self.fractionToVault.remove(key: withdrawID) 
			self.vaultToFractions[vaultId]?.remove(withdrawID)

			return <- token
		}	

		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @Fraction.NFT
			
			let vaultId = token.vaultId
			//Map the fraction's id to it's vault
			self.fractionToVault[token.id] = vaultId
			//Map the vaultId to the fraction's id
			if self.vaultToFractions[vaultId] == nil {
				self.vaultToFractions.insert(key: vaultId, EnumerableSet.UInt64Set())
			} 
			self.vaultToFractions[vaultId]?.add(token.id)
			
			if self.ownedCollections[vaultId] == nil {
				self.ownedCollections[vaultId] <-! Fraction.createEmptyCollection() as! @Fraction.Collection
			}

			//deposit the token into it's corresponding collection
			let collection <- self.ownedCollections.remove(key: vaultId) ?? panic("missing collection")
			collection.deposit(token: <- token)

			// put the collection back in storage
			self.ownedCollections[vaultId] <-! collection
		}

		pub fun getIDs(): [UInt64] {
			return self.fractionToVault.keys
		}

		pub fun getVaultIds(): [UInt64] {
			return self.vaultToFractions.keys
		}

		pub fun getIDsByVault(vaultId: UInt64): [UInt64] {
			return self.vaultToFractions[vaultId]!.values()
		}

		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
			//Find the collection from where a token should be withdrawn
			let vaultId = self.fractionToVault[id] ?? panic("withdraw:no fractions stored for this vaultId")

			// find the nft in the collection and borrow a reference
			return self.ownedCollections[vaultId]?.borrowNFT(id: id)!
		}	

		pub fun borrowFraction(id: UInt64): &Fraction.NFT? {
			//Find the collection from where a token should be withdrawn
			let vaultId = self.fractionToVault[id] ?? panic("withdraw:no fractions stored for this vaultId")

			// find the nft in the collection and borrow a reference
			return self.ownedCollections[vaultId]?.borrowFraction(id: id)!
		}

		pub fun borrowCollection(vaultId: UInt64): &Fraction.Collection? {
			if self.ownedCollections[vaultId] != nil {
				let collectionRef = &self.ownedCollections[vaultId] as! &Fraction.Collection
				return collectionRef
			} else {
				return nil
			}
			
		}

		pub fun withdrawCollection(vaultId: UInt64): @Collection {
			let collection <- self.ownedCollections.remove(key: vaultId) ?? panic("missing collection")
			emit WithdrawCollection(id: vaultId, from: self.owner?.address)
			return <- collection
		}

		destroy() {
			destroy self.ownedCollections
		}
	}

    // public function that anyone can call to create a new empty collection
	pub fun createEmptyCollection(): @NonFungibleToken.Collection {
		return <- create Collection()
	}
	
	pub fun createBulkCollection(): @BulkCollection {
		return <- create BulkCollection()
	}

	// function to mint a group of fractions corresponding to a vault
	access(account) fun mintFractions(
		amount: UInt256, 
		vaultId: UInt64
	): @Collection {

		pre {
			self.fractionSupply[vaultId] ?? 0 as UInt256 < self.maxVaultSupply[vaultId]! : "mintFractions:vault cant mint more fractions!"
		}

		let newCollection <- create Collection()

		var ids: [UInt64] = []
		var i: UInt256 = 0 
		while i < amount {
			newCollection.deposit(token: <- create NFT(
					id: Fraction.totalSupply, 
					vaultId: vaultId
				)
			)
			ids.append(Fraction.totalSupply)
			self.idToVault[self.totalSupply] = vaultId
			self.totalSupply = self.totalSupply + 1
			i = i + 1
		}

		let metadata = FractionData(
			vaultId: vaultId,
			uri: self.vaultToFractionData[vaultId]!.uri,
			curator: self.vaultToFractionData[vaultId]!.curator,
			name: self.vaultToFractionData[vaultId]!.name,
			description: self.vaultToFractionData[vaultId]!.description,
		)

		emit MintFractions(ids: ids, metadata: metadata)

		if self.fractionSupply[vaultId] == nil {
			self.fractionSupply[vaultId] = amount
		} 
		else {
			self.fractionSupply[vaultId] = self.fractionSupply[vaultId]! + amount
		}

		PriceBook.addToSupply(vaultId, amount)
		
		return <- newCollection
	}

	//Get the total fraction suppkly for a given vaultId
	pub fun getFractionSupply(vaultId: UInt64): UInt256 {
		return self.fractionSupply[vaultId]!
	}

    init() {
		self.CollectionPublicPath = /public/fractionalCollection
		self.CollectionPrivatePath = /private/fractionalCollection
		self.CollectionStoragePath = /storage/fractionalCollection
		self.AdministratorStoragePath = /storage/fractionAdmin

		self.totalSupply = 0
		self.baseURI = ""
		self.fractionSupply = {}
		self.idToVault = {}
		self.maxVaultSupply = {}
		self.vaultToFractionData = {}

		self.account.save<@Fraction.BulkCollection>(<- self.createBulkCollection(), to: Fraction.CollectionStoragePath)
		self.account.link<&{Fraction.BulkCollectionPublic}>(Fraction.CollectionPublicPath, target: Fraction.CollectionStoragePath)
		self.account.link<&Fraction.BulkCollection>(Fraction.CollectionPrivatePath, target: Fraction.CollectionStoragePath)

        emit ContractInitialized()	
    }
}