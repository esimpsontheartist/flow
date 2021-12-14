import NonFungibleToken from "./core/NonFungibleToken.cdc"
import TypedMetadata from "./core/TypedMetadata.cdc"
import EnumerableSet from "./EnumerableSet.cdc"
import PriceBook from "./PriceBook.cdc"

pub contract Fraction: NonFungibleToken {

	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath
	pub let CollectionPrivatePath: PrivatePath
	pub let AdministratorStoragePath: StoragePath

    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64
	// The API endpoint for Fraction metadata
	access(account) var uriEndpoint: String
	//A function to set the URI endpoint
	access(account) fun setUriEndpoint(_ uriEndpoint: String) {
		self.uriEndpoint = uriEndpoint
	}
	//Total supply for a given fraction id
	access(account) let fractionSupply: {UInt256: UInt256}

	//Total supply that can be minted for a vault
	access(account) let maxVaultSupply: {UInt256: UInt256}
	//Fraction id to vault id 
	access(account) let idToVault: {UInt64: UInt256}

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

	
	pub struct FractionData {
		pub let vaultId: UInt256
		pub let curator: Address
		pub let name: String
		pub let description: String

        init(
			vaultId: UInt256,
			curator: Address,
			name: String,
			description: String
		) {
			self.vaultId = vaultId
			self.curator = curator
			self.name = name
			self.description = description
        }
	}

	access(account) let vaultToFractionData: {UInt256: FractionData}

	pub event MintFractions(ids: [UInt64], metadata: FractionData)
	
	//The resource that represents the
    pub resource NFT: NonFungibleToken.INFT, TypedMetadata.ViewResolver {

		//global unique fraction ID
        pub let id: UInt64
		//Id to separate fractions by vault
		pub let vaultId: UInt256
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
			vaultId: UInt256,
		) {
            self.id = id
			self.vaultId = vaultId
			self.curator = Fraction.vaultToFractionData[self.vaultId]!.curator
			self.name = Fraction.vaultToFractionData[self.vaultId]!.name
			self.description = Fraction.vaultToFractionData[self.vaultId]!.description
			self.uri = Fraction.uriEndpoint.concat(self.vaultId.toString())
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
		pub fun getIDsByVault(vaultId: UInt256): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
		pub fun borrowFraction(id: UInt64): &Fraction.NFT?
		pub fun balance(): UInt256
	}

    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        
		// dictionary of NFT conforming tokens
		// NFT is a resource type with an `UInt64` ID field
		pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
		// A dictionary to map fractions to their respective vault
		pub let vaultToFractions: {UInt256: EnumerableSet.UInt64Set}

		init () {
			self.ownedNFTs <- {}
			self.vaultToFractions = {}
		}

        // withdraw removes an NFT from the collection and moves it to the caller
		pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
			let vaultId = Fraction.idToVault[token.id]!
			self.vaultToFractions[vaultId]?.remove(token.id)
			emit Withdraw(id: token.id, from: self.owner?.address)

			return <-token
		}

        // deposit takes a NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @Fraction.NFT

			let id: UInt64 = token.id
			let vaultId: UInt256 = token.vaultId
			if self.vaultToFractions[vaultId] == nil {
				self.vaultToFractions.insert(key: vaultId, EnumerableSet.UInt64Set())
			} 

			self.vaultToFractions[vaultId]?.add(id)
			// add the new token to the dictionary which removes the old one
			let oldToken <- self.ownedNFTs[id] <- token

			emit Deposit(id: id, to: self.owner?.address)

			
			destroy oldToken
		}

		// getIDs returns an array of the IDs that are in the collection
		pub fun getIDs(): [UInt64] {
			return self.ownedNFTs.keys
		}

		// getIDsByVault returns an array of the IDs in the collection corresponding to a vaultId
		pub fun getIDsByVault(vaultId: UInt256): [UInt64] {
			return self.vaultToFractions[vaultId]!.values()
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
	
	pub fun createEmptyFractionCollection(): @Fraction.Collection {
		return <- create Collection()
	}

	// function to mint a group of fractions corresponding to a vault
	access(account) fun mintFractions(
		amount: UInt256, 
		vaultId: UInt256
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
	pub fun getFractionSupply(vaultId: UInt256): UInt256 {
		return self.fractionSupply[vaultId]!
	}

    init() {
		self.CollectionPublicPath = /public/fractionalCollection
		self.CollectionPrivatePath = /private/fractionalCollection
		self.CollectionStoragePath = /storage/fractionalCollection
		self.AdministratorStoragePath = /storage/fractionAdmin

		self.totalSupply = 0
		self.uriEndpoint = ""
		self.fractionSupply = {}
		self.idToVault = {}
		self.maxVaultSupply = {}
		self.vaultToFractionData = {}

		self.account.save<@NonFungibleToken.Collection>(<- Fraction.createEmptyCollection(), to: Fraction.CollectionStoragePath)
		self.account.link<&{Fraction.CollectionPublic}>(Fraction.CollectionPublicPath, target: Fraction.CollectionStoragePath)
		self.account.link<&Fraction.Collection>(Fraction.CollectionPrivatePath, target: Fraction.CollectionStoragePath)

        emit ContractInitialized()	
    }
}