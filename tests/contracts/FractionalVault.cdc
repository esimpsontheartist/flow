import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import PriceBook from "./PriceBook.cdc"
import Fraction from "./Fraction.cdc"
import Clock from "./Clock.cdc"

//////////////////////////////////////
/// Fractional NFT Vault contract ///
/////////////////////////////////////

pub contract FractionalVault {

    /// -----------------------------------
    /// ----------- Factory ---------------
    /// -----------------------------------

    /// @notice the number of NFT vaults
    pub var vaultCount: UInt256

    /// @notice the address where the vaults get minted to (address that has it's keys revoked)
    pub let vaultAddress: Address

    pub let VaultStoragePath: StoragePath
	pub let VaultPublicPath: PublicPath

    //Vault settings 
    pub struct Settings {
        // the address that receives auction fees
        pub var feeReceiver: Capability<&{FungibleToken.Receiver}>? 

        init() {
            self.feeReceiver = nil
        }

        access(account) fun setFeeReceiver(receiver: Capability<&{FungibleToken.Receiver}>) {
            pre {
                receiver != nil: "fees cannot go to nil capability"
            }
            emit UpdateFeeReceiver(old: self.feeReceiver!.address, new: receiver.address)
            self.feeReceiver = receiver
        }

    }

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
    pub let vaultToFractionData: {UInt256: FractionData}

    /// @notice settings constant controlled by governance
    access(account) let settings: Settings

    //Vault settings Events
    pub event UpdateFeeReceiver(old: Address, new: Address)

    //enum for auction state
    pub enum State: UInt8 {
        pub case inactive
        pub case live
        pub case ended
        pub case redeemed
    }

    //struct for the underlying nft data
    pub struct Media {
        pub let data: String
        pub let contentType: String
        pub let protocol: String

        init(data: String, contentType: String, protocol: String) {
			self.data = data
			self.protocol = protocol
			self.contentType = contentType
		}
    }

    pub struct Display{
		pub let name: String
		pub let thumbnail: String
		pub let description: String
		pub let source: String

		init(name: String, thumbnail: String, description: String, source: String) {
			self.source = source
			self.name = name
			self.thumbnail = thumbnail
			self.description = description
		}
	}

    /// -----------------------------------
    /// ------ Vault Events ---------------
    /// -----------------------------------
    /// TODO: improve events
    /// @notice An event emitted when a user updates their price
    pub event PriceUpdate(fractionsOwner: Address, price: UFix64);
    /// @notice An event emitted when a user updates their price
    pub event PricesRemoved(fractionsOwner: Address);
    /// @notice An event emitted when an auction starts
    pub event Start(buyer: Address, price: UFix64);
    /// @notice An event emitted when a bid is made
    pub event Bid(buyer: Address, price: UFix64);
    /// @notice An event emitted when an auction is won
    pub event Won(buyer: Address, price: UFix64);
    /// @notice An event emitted when someone redeems all tokens for the NFT
    pub event Redeem(redeemer: Address);
    /// @notice An event emitted when someone cashes in Fractions for FLOW from an NFT sale
    pub event Cash(owner: Address, flow: UFix64);
    //Mint event
    pub event Mint(underlyingOwner: Address, vaultId: UInt256);
    // @notice An envet emitted when a vault resource is initialized
    pub event Initialized(id: UInt256);


    pub fun updateFractionPrice(_ vaultId: UInt256, collection: &Fraction.Collection, startId: UInt64, amount: UInt256, new: UFix64) {
        
        let fractionsOwner = collection.owner?.address!

        let fractionIds = collection.vaultToFractions[vaultId]!.values()

        if fractionIds.length == 0 {
            return
        }

        var i: UInt256 = 0
        var begin = startId
        let fractions: [UInt64] = []
        while i < amount {
            let value = fractionIds[begin]
            begin = begin + 1
            fractions.append(value)
            i = i + 1
        }

        PriceBook.addToPrice(vaultId, UInt256(fractions.length), new)

        //Update the price for fractionsPrices and remove old prices
        for id in fractions {
            let fraction = collection.borrowFraction(id: id)
            let id = fraction!.id
            let nested = PriceBook.fractionPrices[vaultId] ?? {}
            if nested[id] != nil {
                PriceBook.removeFromPrice(vaultId, 1, nested[id]!)
            }
            nested[id] = new
            PriceBook.fractionPrices[vaultId] = nested
        }

        emit PriceUpdate(fractionsOwner: fractionsOwner, price: new)
    }

    pub resource Vault {

        pub let id: UInt256

        //expose all these things through functions
        access(account) let settings: Settings

        //The vault that holds fungible tokens for an auction
        access(contract) let bidVault: @FungibleToken.Vault
        //The type of Fungible Token that the vault accepts
        access(contract) let bidVaultType: Type
        //The collection for the fractions
        access(contract) var fractions: @Fraction.Collection
        //Collection of the NFTs the user will fractionalize (UInt64 is meant to be the NFT's uuid)
        access(contract) var underlying: @NonFungibleToken.Collection
        //Type of collection that was deposited
        access(contract) let underlyingType: Type
        //address that can receive the fractions
        pub let curator: Capability<&Fraction.Collection>
        //Max supply the user allows to exist
        access(contract) var maxSupply: UInt64
        //Min supply that the contract allows
        access(contract) var minSupply: UInt64
        //Hold media for the underlying nfts
        access(contract) let medias: {UInt64: Media}
        //Hold display information for the underlying
        access(contract) let displays: {UInt64: Display}

        // Auction information// 
        pub var auctionEnd: UFix64?
        pub var auctionLength: UFix64
        pub var livePrice: UFix64?
        pub var winning: Capability<&{NonFungibleToken.CollectionPublic}>?
        pub var refundCapability: Capability<&{FungibleToken.Receiver}>?
        pub var auctionState: State?

        init(
            id: UInt256,
            underlying: @NonFungibleToken.Collection,
            underlyingType: Type,
            bidVault: @FungibleToken.Vault,
            bidVaultType: Type,
            curator: Capability<&Fraction.Collection>,
            maxSupply: UInt64,
            medias: {UInt64: Media},
            displays: {UInt64: Display},
            fractionData: FractionalVault.FractionData
        ) {
            pre {
                underlyingType.isInstance(underlyingType) : "init:type for the underlying collection does not conform to the NFT standard"
                bidVaultType.isInstance(bidVaultType) : "init:type for the underlying collection does not conform to the NFT standard"
                curator.check() == true : "init:curator capability must be linked"
                medias.length == underlying.getIDs().length : "init:length of medias does not equal the length of the collection"
                displays.length == underlying.getIDs().length : "init:length of displays does not equal the length of the collection"

            }

            post {
                maxSupply >= self.minSupply : "init:max supply cannot be less than the minimum allowed supply"
            }

            self.id = id
            self.underlying <- underlying
            self.underlyingType = underlyingType
            self.bidVault <- bidVault
            self.bidVaultType = bidVaultType
            self.curator = curator
            self.settings = FractionalVault.settings
            self.auctionLength = 172800.0 //2 days in seconds 
            self.auctionState = State.inactive
            self.maxSupply = maxSupply
            self.minSupply = 1000
            self.medias = medias
            self.displays = displays

            //Set data for the fractions that will be minted

            // Resources
            self.fractions <- Fraction.createEmptyFractionCollection()
            
            //optional nil variables
            self.auctionEnd = nil
            self.livePrice = nil
            self.winning = nil
            self.refundCapability = nil
            
            emit Initialized(id: id)
        }
        
        pub fun isLivePrice(price: UFix64): Bool {
            return PriceBook.prices[self.id]!.contains(price);
        }

        // function to borrow a reference to the underlying collection
        pub fun borrowUnderlying(): &{NonFungibleToken.CollectionPublic} {
            return &self.underlying as &{NonFungibleToken.CollectionPublic}
        }

        pub fun getUnderlyingType(): Type {
            return self.underlyingType
        }

        pub fun borrowBidVault(): &{FungibleToken.Balance} {
            return &self.bidVault as &{FungibleToken.Balance}
        }

        pub fun getBidVaultType(): Type {
            return self.bidVaultType
        }

        pub fun borrowCollection() : &{Fraction.CollectionPublic} {
            return &self.fractions as! auth &{Fraction.CollectionPublic}
        }

        pub fun getcurator(): Address {
            return self.curator.address
        }

        access(contract) fun sendFungibleToken(to: Capability<&{FungibleToken.Receiver}>, value: UFix64) {
            //borrow a capability for the vault of the 'to' address
            let toVault = to.borrow() ?? panic("Could not borrow a reference to the account receiver")
            //withdraw 'value' from the bidVault
            toVault.deposit(from: <- self.bidVault.withdraw(amount: value))
        }
        

        /// @notice kick off an auction. Must send reservePrice in the correct Fungible Token
        pub fun start(
            ftVault: @FungibleToken.Vault, 
            refund: Capability<&{FungibleToken.Receiver}>,
            bidder: Capability<&{NonFungibleToken.CollectionPublic}>
        ) {
            pre {
                self.auctionState == State.inactive : "start:no auction starts"
                bidder.check() == true : "start:collection capability must be linked"
                refund.check() == true : "start:refund capability must be linked"
                ftVault.isInstance(self.bidVaultType) : "start:bid is not the requested fungible token"
                ftVault.balance >= PriceBook.reservePrice(self.id).reserve : "start:too low bid"
                PriceBook.reservePrice(self.id).voting * 2 >= Fraction.fractionSupply[self.id]! : "start:not enough voters"
            }

            let bidderRef= bidder.borrow() ?? panic("start:could not borrow a reference from the bidders capability")
            assert(bidderRef.isInstance(self.underlyingType), message: "start:bidder's collection capability does not match the vault")

            let refundRef = refund.borrow() ?? panic("start:could not borrow a reference from the refund capability")
            assert(refundRef.isInstance(self.bidVaultType), message: "start:refund capability is not the requested token")

            self.auctionEnd = Clock.time() + self.auctionLength
            self.auctionState = State.live

            self.livePrice = ftVault.balance
            self.winning = bidder
            self.refundCapability = refund

            //Deposit the bid into the vault
            self.bidVault.deposit(from: <- ftVault)

            emit Start(buyer: self.winning!.address, price: self.livePrice!) 
        }

        //Place a condition that the auction starter most have a WrappedCollection capability
        pub fun bid(
            ftVault: @FungibleToken.Vault, 
            refund: Capability<&{FungibleToken.Receiver}>,
            bidder: Capability<&{NonFungibleToken.CollectionPublic}>
        ) {
            pre {
                self.auctionState == State.live : "bid:auction is not live"
                bidder.check() == true : "bid:wrapped collection capability must be linked"
                refund.check() == true : "bid:refund capability must be linked"
                ftVault.isInstance(self.bidVaultType) : "bid:bid is not the requested fungible token"
                ftVault.balance >= self.livePrice! * 1.05 : "bid:too low bid"
                Clock.time() < self.auctionEnd! : "bid:auction end"
            }

            let bidderRef = bidder.borrow() ?? panic("bid:could not borrow a reference for the bidders capability")
            assert(bidderRef.isInstance(self.underlyingType), message: "bid:bidder's collection capability does not match the vault")

            let refundRef = refund.borrow() ?? panic("bid:could not borrow a reference from the refund capability")
            assert(refundRef.isInstance(self.bidVaultType), message: "bid:refund capability is not the requested token")
            //Add block height checks
            //900 is 15 minutes in seconds (for timestamp calculations)
            if self.auctionEnd! - Clock.time() <= 900.0 {
                self.auctionEnd = self.auctionEnd! + 900.0
            }
            
            //refund the last bidder
            self.sendFungibleToken(to: self.refundCapability!, value: self.livePrice!);
            //update the refund capability
            self.refundCapability = refund
            
            self.livePrice = ftVault.balance
            self.winning = bidder

            //Deposit the bid into the vault
            self.bidVault.deposit(from: <- ftVault)
            emit Bid(buyer: self.winning!.address, price: self.livePrice!)
        }

        pub fun end() {
            pre {
                self.auctionState == State.live : "end:vault has already closed"
                Clock.time() >= self.auctionEnd! : "end:auction live"
            }
            
            //get capabilit of the winners collection
            let collection = self.winning!.borrow() ?? panic("Auction winner does not have a capability to receive the underlying")

            // transfer NFT to winner
            let keys = self.underlying.getIDs()
            for key in keys {
                collection.deposit(token: <- self.underlying.withdraw(withdrawID: key))
            }
            //change auction state
            self.auctionState = State.ended

            if self.settings.feeReceiver != nil {
                self.sendFungibleToken(to: self.settings.feeReceiver!, value: (self.livePrice! * 0.025))
            }

            emit Won(buyer: self.winning!.address, price: self.livePrice!)
        }

        /// @notice  function to burn all fractions and receive the underlying
        pub fun redeem(collection: &Fraction.Collection, amount: UInt256, redeemer: Capability<&{NonFungibleToken.CollectionPublic}>) {
            pre {
                self.auctionState == State.inactive : "redeem:no redeeming"
                redeemer.check() == true : "redeem:redeemer's collection capability must be linked"
                collection.vaultToFractions[self.id]!.length() == Fraction.fractionSupply[self.id]! : "redeem:collection does not contain all fractions"
            }

            let bidderRef = redeemer.borrow() ?? panic("redeem:could not borrow a reference for the bidders capability")
            assert(bidderRef.isInstance(self.underlyingType), message: "redeem:bidder's collection capability does not match the vault")

            //burn fractions
            var i: UInt256 = 0
            for fractionId in collection.vaultToFractions[self.id]!.values() {
                destroy collection.withdraw(withdrawID: fractionId)
                i = i + 1
                if i == amount {
                    break
                }
            }
            
            if Fraction.fractionSupply[self.id]! == 0 {

                let redeemersCollection = redeemer.borrow() ?? panic("redeem:could not borrow a reference to the redeemer's collection capability")

                //transfer NFTs to the owner of the fractions
                let keys = self.underlying.getIDs()
                for key in keys {
                    redeemersCollection.deposit(token: <- self.underlying.withdraw(withdrawID: key))
                }

                self.auctionState = State.redeemed

                emit Redeem(redeemer: redeemer.address)
            }
        }

        //Might want to change this to a capability
        pub fun cash(collection: @NonFungibleToken.Collection, collector: Capability<&{FungibleToken.Receiver}>) {
            pre {
                self.auctionState == State.ended : "cash:vault not closed yet"

                collector.check() == true : "cash:collector capability is not linked"
            }
            
            let collectorRef = collector.borrow() 
            ?? panic("cash:could not borrow a reference from the collector's fungible token capability")
            assert(collectorRef.isInstance(self.bidVaultType), message: "cash:collector's capability is not the requested token")

            let fractions <- collection as! @Fraction.Collection

            assert(fractions.balance() > 0, message: "cash:no tokens to cash out")
            assert(fractions.balance() == fractions.vaultToFractions[self.id]!.length(), message: "cash: cannot cash fractions from another vault")
            //calculate share of the total fraction supply for the vault (Need to check the math)
            var share = (UFix64(fractions.balance()) * self.bidVault.balance) / UFix64(Fraction.fractionSupply[self.id]!)

            //burn the fractions
            destroy fractions

            //sendFlow
            self.sendFungibleToken(to: collector, value: share)

            emit Cash(owner: collector.address, flow: share)
        }

        //Resource destruction
        //Add more logic behind conditions before a vault and other resources are destructed
        destroy() {
            destroy self.underlying
            destroy self.bidVault
            destroy self.fractions
        }

    }

    pub resource interface VaultCollectionPublic {
        pub fun depositVault(vault: @FractionalVault.Vault)
		pub fun getIDs(): [UInt256]
		pub fun borrowVault(id: UInt256): &FractionalVault.Vault?
    }

    pub resource VaultCollection: VaultCollectionPublic {
        //dictionary of Vault conforming resources
        //Vault is a resource type with a `UInt256` ID field
        pub var vaults: @{UInt256: FractionalVault.Vault}

        init() {
            self.vaults <- {}
        }

        // takes a vault and adds it to the vault dictionary
        pub fun depositVault(vault: @FractionalVault.Vault) {
            let vault <- vault 

            let id: UInt256 = vault.id

            let oldVault <- self.vaults[id] <- vault

            //add event depositing a vault

            destroy oldVault
        }

        pub fun getIDs(): [UInt256] {
            return self.vaults.keys
        }

        // borrowVaultgets a reference to a Vault in the collection
		// so that the caller can read its metadata and call its methods
        pub fun borrowVault(id: UInt256): &FractionalVault.Vault? {
            if self.vaults[id] != nil {
                let ref = &self.vaults[id] as auth &FractionalVault.Vault
                return ref 
            } else {
                return nil
            }
        }

        

        destroy() {
			destroy self.vaults
		}
    }

    //function that sets up a collection to hold the vault
    pub fun createEmptyCollection(): @FractionalVault.VaultCollection {
        return <- create VaultCollection()
    }

    /// @notice the function to mint a new vault
    /// @param collection the collection for the underlying set of NFTS
    /// @return the ID of the vault
    pub fun mintVault(
        collection: @NonFungibleToken.Collection, 
        collectionType: Type, 
        bidVault: @FungibleToken.Vault,
        bidVaultType: Type,
        curator: Capability<&Fraction.Collection>,
        maxSupply: UInt64,
        medias: {UInt64: Media},
        displays: {UInt64: Display},
        fractionData: FractionData
    ) {

        pre {
            curator.check() == true : "mintVault:curator capability must be linked"
        }

        //Initialize a vault
        let vault <- create Vault(
            id: self.vaultCount, 
            underlying: <- collection, 
            underlyingType: collectionType, 
            bidVault: <- bidVault, 
            bidVaultType: bidVaultType,
            curator: curator,
            maxSupply: maxSupply,
            medias: medias,
            displays: displays,
            fractionData: fractionData
        )

        
        emit Mint(underlyingOwner: vault.curator.address, vaultId: vault.id);

        
        let vaultCollection = getAccount(self.vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
        ?? panic("Could not borrow a reference to the Fractional Vault Collection")

        vaultCollection.depositVault(vault: <- vault)

        self.vaultCount =  self.vaultCount + 1
    }

    /// @notice the function to mint a new vault
    /// @param collection the collection for the underlying set of NFTS
    /// @return the ID of the vault
    //Change function accesibility 
    pub fun mintVaultFractions(
        vaultId: UInt256, 
        curator: Capability<&Fraction.Collection>,
    ){

        pre {
            curator.check() == true : "mintVaultFractions:curator capability must be linked"
        }
        
        //Get capability for the vault
        let vaultCollection = getAccount(self.vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
        ?? panic("Could not borrow a reference to the Fractional Vault Collection")

        let vault = vaultCollection.borrowVault(id: vaultId) ?? panic("Could not borrow a reference for the given VaultId")

        assert(vault.curator.address == curator.address, message: "this address is not permitted to mint this vault")
        
        //mint the fractions
        let fractions <- Fraction.mintFractions(
            amount: 100, 
            vaultId: self.vaultCount - 1,
            name: self.vaultToFractionData[self.vaultCount - 1]!.name,
            thumbnail: self.vaultToFractionData[self.vaultCount - 1]!.thumbnail,
            description: self.vaultToFractionData[self.vaultCount - 1]!.description,
            source: self.vaultToFractionData[self.vaultCount - 1]!.source,
            media: self.vaultToFractionData[self.vaultCount - 1]!.media,
            contentType: self.vaultToFractionData[self.vaultCount - 1]!.contentType,
            protocol: self.vaultToFractionData[self.vaultCount - 1]!.protocol
        )

        //capability to deposit fractions to the owner of the underlying NFT
        let curator =  getAccount(vault.curator.address)
        let fractionCapability = curator.getCapability(Fraction.CollectionPublicPath).borrow<&{Fraction.CollectionPublic}>() 
        ?? panic("Could not borrow a reference to the account receiver")
        //Receive the fractions
        let fractionIds = fractions.getIDs()
        for fractionId in fractionIds {
            fractionCapability.deposit(token: <- fractions.withdraw(withdrawID: fractionId))
        }
        //destroy the fraction resources since they have been moved
        destroy fractions
    }

    init(vaultAddress: Address) {
        //Hard coded for now, should switch to using init() args for testnet deployment
        self.vaultAddress = vaultAddress
        self.vaultCount = 0
        self.settings = Settings()
        self.vaultToFractionData = {}

        self.VaultPublicPath = /public/fractionalVault
        self.VaultStoragePath = /storage/fractionalVault

        self.account.save<@FractionalVault.VaultCollection>(<- FractionalVault.createEmptyCollection(), to: FractionalVault.VaultStoragePath)
		self.account.link<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath, target: FractionalVault.VaultStoragePath)
    }
}
 