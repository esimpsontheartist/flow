import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import FUSD from "./FUSD.cdc"

pub contract TypedMetadata {

	/// The main ViewResolver that the modified NFT in this repo needs to implement
	pub resource interface ViewResolver {
		pub fun getViews() : [Type]
		pub fun resolveView(_ view:Type): AnyStruct
	}

	//A resource interface we give the ViewResolverCollection to signal that they contain resources with view resolvers
	// Other resources collections that are not NFT can include this interface to be discoverable
	pub resource interface ViewResolverCollection {
		pub fun borrowViewResolver(id: UInt64): &{ViewResolver}
		pub fun getIDs(): [UInt64]
	}

	/// This struct interface is used on a contract level to convert from one View to another. 
	/// See Dandy nft for an example on how to convert one type to another
	pub struct interface ViewConverter {
		pub let to: Type
		pub let from: Type

		pub fun convert(_ value:AnyStruct) : AnyStruct
	}

	/// A struct interface for Royalty agreed upon by @dete, @rheaplex, @bjartek 
	pub struct interface Royalty {

		/// if nil cannot pay this type
		/// if not nill withdraw that from main vault and put it into distributeRoyalty 
		pub fun calculateRoyalty(type:Type, amount:UFix64) : UFix64?

		/// call this with a vault containing the amount given in calculate royalty and it will be distributed accordingly
		pub fun distributeRoyalty(vault: @FungibleToken.Vault) 

		/// generate a string that represents all the royalties this NFT has for display purposes
		pub fun displayRoyalty() : String?  

	}

	// TODO: Should this contain links to your NFT in the originating/source solution? An simple Dictionary of String:String would do
	pub struct Display{
		pub let name: String
		pub let thumbnail: String
		pub let description: String
		pub let source: String

		init(name:String, thumbnail: String, description: String, source:String) {
			self.source=source
			self.name=name
			self.thumbnail=thumbnail
			self.description=description
		}
	}

	pub struct Medias {
		pub let media : {String:  Media}

		init(_ items: {String: Media}) {
			self.media=items
		}
	}

	/*
	Examples here are:
	An Image on IPFS:
	data: QmRAQB6YaCyidP37UdDnjFY5vQuiBrcqdyoW1CuDgwxkD4
	contentType: image/jpeg
	protocol: ipfs

	An http image
	data: https://test.find.xyz/find.png
	contentType: image/jpeg
	protocol: http

	An onChain image
	data: data:image/png;base64,SOMEPNGDATAURI/wD/
	contentType: image/jpeg
	protocol: data

	The problem here is that the onChain image can be quite large and you might not want to resolve those every time you fetch down the Meida view. So what if we made a method on the struct that allow you to retrieve the data/content instead?

	*/
	pub struct Media {
		//TODO: should data here be a method? or should there be an method aswell with default impl since you might want lazy laoading content
		pub let data: String
		pub let contentType: String
		pub let protocol: String

		init(data:String, contentType: String, protocol: String) {
			self.data=data
			self.protocol=protocol
			self.contentType=contentType
		}
	}

	// This is an example taken from Versus
	pub struct CreativeWork {
		pub let artist: String
		pub let name: String
		pub let description: String
		pub let type: String

		init(artist: String, name: String, description: String, type: String) {
			self.artist=artist
			self.name=name
			self.description=description
			self.type=type
		}
	}

	//Simple struct signaling that this is editioned
	pub struct Editioned {
		pub let edition: UInt64
		pub let maxEdition: UInt64

		init(edition:UInt64, maxEdition:UInt64){
			self.edition=edition
			self.maxEdition=maxEdition
		}
	}


	// Would this work for rarity? Hoodlums, flovatar, Basicbeasts? comments?
	pub struct Rarity{
		pub let rarity: UFix64
		pub let rarityName: String
		pub let parts: {String: RarityPart}

		init(rarity: UFix64, rarityName: String, parts:{String:RarityPart}) {
			//TODO: pre that rarity cannot be above 100.0
			self.rarity=rarity
			self.rarityName=rarityName
			self.parts=parts
		}
	}

	pub struct RarityPart{

		pub let rarity: UFix64
		pub let rarityName: String
		pub let name: String

		init(rarity: UFix64, rarityName: String, name:String) {

			self.rarity=rarity
			self.rarityName=rarityName
			self.name=name
		}

	}

	//Could this work to mark that something is for sale?
	pub struct ForSale{
		pub let types: [Type] //these are the types of FT that this token can be sold as
		pub let price: UFix64

		init(types: [Type], price: UFix64) {
			self.types=types
			self.price=price
		}
	}
}