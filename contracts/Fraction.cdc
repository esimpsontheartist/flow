import NonFungibleToken from "./NonFungibleToken.cdc"
import EnumerableSet from "./EnumerableSet.cdc"
import PriceBook from "./PriceBook.cdc"

pub contract Fraction: NonFungibleToken {

	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath
	pub let CollectionPrivatePath: PrivatePath
	pub let AdministratorStoragePath: StoragePath

    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64

	//Total supply for a given fraction id
	access(account) let fractionSupply: {UInt256: UInt256}

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
		pub let name: String
		pub let thumbnail: String
		pub let description: String
		pub let source: String
		pub let media: String
		pub let contentType: String
		pub let protocol: String

        init(
			vaultId: UInt256,
			name: String,
			thumbnail: String,
			description: String,
			source: String,
			media: String,
			contentType: String,
			protocol: String
		) {
			self.vaultId = vaultId
			self.name = name 
			self.thumbnail = thumbnail 
			self.description = description 
			self.source = source 
			self.media = media 
			self.contentType = contentType
			self.protocol = protocol 
        }
	}

    //mapping of vaultId to Fraction Data
	//this data gets stored in order to be used by other contracts that mint fractions during a transaction
    priv let vaultToFractionData: {UInt256: FractionData}

	pub resource Administrator { 
		pub fun setVaultFractionData(vaultId: UInt256, fractionData: FractionData) {
			Fraction.vaultToFractionData[vaultId] = fractionData
		}
	}
	

	pub struct Metadata { 
		pub let vaultId: UInt256
		pub let name: String
		pub let thumbnail: String
		pub let description: String
		pub let source: String
		pub let media: String
		pub let contentType: String
		pub let protocol: String

		init(
			vaultId: UInt256,
			name: String,
			thumbnail: String,
			description: String,
			source: String,
			media: String,
			contentType: String,
			protocol: String

		) {
			self.vaultId = vaultId
			self.name = name
			self.thumbnail = thumbnail
			self.description = description
			self.source = source
			self.media = media
			self.contentType = contentType
			self.protocol = protocol
		}
	}

	pub event MintFractions(ids: [UInt64], metadata: Metadata)
	
	pub resource interface Public {
		pub let id: UInt64
		pub let vaultId: UInt256
		pub let name: String
		pub let thumbnail: String
		pub let description: String
		pub let source: String
		pub let media: String
		pub let contentType: String
		pub let protocol: String
	}

	//The resource that represents the
    pub resource NFT: NonFungibleToken.INFT, Public {

		//global unique fraction ID
        pub let id: UInt64
		//Id to separate fractions by vault
		pub let vaultId: UInt256
		//name of the fraction collection
		pub let name: String
		//thumbnail to be shown in the blocto wallet
		pub let thumbnail: String
		//description
		pub let description: String
		//From what protocol does this NFT come from
		pub let source: String
		//data for the media
		pub let media: String
		//type of the content for the media (jpeg, gif, etc)
		pub let contentType: String
		//protocol of the media (ipfs, http, etc)
		pub let protocol: String

        init(
			id: UInt64, 
			vaultId: UInt256,
			name: String,
			thumbnail: String,
			description: String,
			source: String,
			media: String,
			contentType: String,
			protocol: String
		) {
            self.id = id
			self.vaultId = vaultId
			self.name = name 
			self.thumbnail = thumbnail 
			self.description = description 
			self.source = source 
			self.media = media 
			self.contentType = contentType
			self.protocol = protocol 
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
		pub fun borrowFraction(id: UInt64): &{Fraction.Public}?
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
		pub fun borrowFraction(id: UInt64): &{Fraction.Public}? {
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
			self.fractionSupply[vaultId] ?? 0 as UInt256 < 10000 : "mintFractions:vault cannot mint more fractions!"
			self.vaultToFractionData[vaultId] != nil : "mintFractions:no data to mint the fractions"
		}

		let newCollection <- create Collection()

		let name = self.vaultToFractionData[vaultId]!.name
		let thumbnail = self.vaultToFractionData[vaultId]!.thumbnail
		let description = self.vaultToFractionData[vaultId]!.description
		let source = self.vaultToFractionData[vaultId]!.source
		let media = self.vaultToFractionData[vaultId]!.media
		let contentType = self.vaultToFractionData[vaultId]!.contentType
		let protocol = self.vaultToFractionData[vaultId]!.protocol

		var ids: [UInt64] = []
		var i: UInt256 = 0 
		while i < amount {
			newCollection.deposit(token: <- create NFT(
					id: Fraction.totalSupply, 
					vaultId: vaultId,
					name: name,
					thumbnail: thumbnail,
					description: description,
					source: source,
					media: media,
					contentType: contentType,
					protocol: protocol
				)
			)
			ids.append(Fraction.totalSupply)
			self.idToVault[self.totalSupply] = vaultId
			self.totalSupply = self.totalSupply + 1
			i = i + 1
		}

		let metadata = Metadata(
			vaultId: vaultId,
			name: self.vaultToFractionData[vaultId]!.name,
			thumbnail: self.vaultToFractionData[vaultId]!.thumbnail,
			description: self.vaultToFractionData[vaultId]!.description,
			source: self.vaultToFractionData[vaultId]!.source,
			media: self.vaultToFractionData[vaultId]!.media,
			contentType: self.vaultToFractionData[vaultId]!.contentType,
			protocol: self.vaultToFractionData[vaultId]!.protocol
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
		self.fractionSupply = {}
		self.idToVault = {}
		self.vaultToFractionData = {}

		let admin <- create Administrator()
        self.account.save(<- admin, to: self.AdministratorStoragePath)
		self.account.save<@NonFungibleToken.Collection>(<- Fraction.createEmptyCollection(), to: Fraction.CollectionStoragePath)
		self.account.link<&{Fraction.CollectionPublic}>(Fraction.CollectionPublicPath, target: Fraction.CollectionStoragePath)
		self.account.link<&Fraction.Collection>(Fraction.CollectionPrivatePath, target: Fraction.CollectionStoragePath)

        emit ContractInitialized()	
    }
}