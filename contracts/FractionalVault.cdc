import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import PriceBook from "./PriceBook.cdc"
import Fraction from "./Fraction.cdc"

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
    pub let AdministratorStoragePath: StoragePath

    pub event ContractInitialized()


    pub var feeReceiver: Capability<&{FungibleToken.Receiver}>?

    

    pub resource Administrator {
        pub fun setFeeReceiver(receiver: Capability<&{FungibleToken.Receiver}>) {
            pre {
                receiver != nil: "fees cannot go to nil capability"
            }
            emit UpdateFeeReceiver(old: FractionalVault.feeReceiver!.address, new: receiver.address)
            FractionalVault.feeReceiver = receiver
        }
    }

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
    pub event PriceUpdate(fractionsOwner: Address, amount: UInt256, price: UFix64);
    /// @notice An event emitted when an auction starts
    pub event Start(buyer: Address, price: UFix64, auctionEnd: UFix64);
    /// @notice An event emitted when a bid is made
    pub event Bid(buyer: Address, price: UFix64, auctionEnd: UFix64);
    /// @notice An event emitted when an auction is won
    pub event Won(buyer: Address, price: UFix64, ids: [UInt64]);
    /// @notice An event emitted when someone redeems all tokens for the NFT
    pub event Redeem(redeemer: Address, ids: [UInt64]);
    /// @notice An event emitted when someone cashes in Fractions for FLOW from an NFT sale
    pub event Cash(owner: Address, amount: UFix64);
    // @notice An envet emitted when a vault resource is initialized
    pub event VaultMinted(
        id: UInt256, 
        curator: Address,
        bidVaultType: Type,
        underlyingType: Type,
        maxSupply: UInt256,
        medias: {UInt64: Media},
        displays: {UInt64 : Display}
    );


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

        emit PriceUpdate(fractionsOwner: fractionsOwner, amount: amount, price: new)
    }

    pub resource Vault {

        pub let id: UInt256

        //address that can receive the fractions
        pub let curator: Capability<&Fraction.Collection>

        //The vault that holds fungible tokens for an auction
        access(contract) let bidVault: @FungibleToken.Vault
        //The type of Fungible Token that the vault accepts
        pub let bidVaultType: Type
        //The collection for the fractions
        access(contract) var fractions: @Fraction.Collection
        //Collection of the NFTs the user will fractionalize (UInt64 is meant to be the NFT's uuid)
        access(contract) var underlying: @NonFungibleToken.Collection
        //Type of collection that was deposited
        pub let underlyingType: Type
        //Max supply the user allows to exist
        access(contract) var maxSupply: UInt256
        //Min supply that the contract allows
        access(contract) var minSupply: UInt256
        //Hold media for the underlying nfts
        pub let medias: {UInt64: Media}
        //Hold display information for the underlying
        pub let displays: {UInt64: Display}

        //varaible used for redemption calculations
        access(self) var redemptionAmount: UInt256

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
            maxSupply: UInt256,
            medias: {UInt64: Media},
            displays: {UInt64: Display}
        ) {
            pre {
                //curator.check() == true : "init:curator capability must be linked"
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
            self.auctionLength = 172800.0 //2 days in seconds 
            self.auctionState = State.inactive
            self.maxSupply = maxSupply
            self.redemptionAmount = maxSupply
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
            
            emit VaultMinted(id: id, 
                curator: curator.address,
                bidVaultType: bidVaultType,
                underlyingType: underlyingType,
                maxSupply: maxSupply,
                medias: medias,
                displays: displays
            )
        }

        pub fun isLivePrice(price: UFix64): Bool {
            return PriceBook.prices[self.id]!.contains(price);
        }

        // function to borrow a reference to the underlying collection
        // can be used to deposit to the vault
        pub fun borrowUnderlying(): &{NonFungibleToken.CollectionPublic} {
            return &self.underlying as &{NonFungibleToken.CollectionPublic}
        }

        pub fun vaultBalance(): &{FungibleToken.Balance} {
            return &self.bidVault as &{FungibleToken.Balance}
        }

        pub fun borrowFractionCollection() : &{Fraction.CollectionPublic} {
            return &self.fractions as! auth &{Fraction.CollectionPublic}
        }

        access(self) fun sendFungibleToken(to: Capability<&{FungibleToken.Receiver}>, value: UFix64) {
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
                PriceBook.reservePrice(self.id).voting * 2 >= self.maxSupply : "start:not enough voters"
                bidder.check() == true : "start:collection capability must be linked"
                refund.check() == true : "start:refund capability must be linked"
                ftVault.isInstance(self.bidVaultType) : "start:bid is not the requested fungible token"
                ftVault.balance >= PriceBook.reservePrice(self.id).reserve : "start:too low bid"
            }

            let bidderRef= bidder.borrow() ?? panic("start:could not borrow a reference from the bidders capability")
            assert(bidderRef.isInstance(self.underlyingType), message: "start:bidder's collection capability does not match the vault")

            let refundRef = refund.borrow() ?? panic("start:could not borrow a reference from the refund capability")
            assert(refundRef.isInstance(self.bidVaultType), message: "start:refund capability is not the requested token")

            self.auctionEnd = getCurrentBlock().timestamp + self.auctionLength
            self.auctionState = State.live

            self.livePrice = ftVault.balance
            self.winning = bidder
            self.refundCapability = refund

            //Deposit the bid into the vault
            self.bidVault.deposit(from: <- ftVault)

            emit Start(buyer: self.winning!.address, price: self.livePrice!, auctionEnd: self.auctionEnd! ) 
        }

        pub fun bid(
            ftVault: @FungibleToken.Vault, 
            refund: Capability<&{FungibleToken.Receiver}>,
            bidder: Capability<&{NonFungibleToken.CollectionPublic}>
        ) {
            pre {
                self.auctionState == State.live : "bid:auction is not live"
                getCurrentBlock().timestamp < self.auctionEnd! : "bid:auction end"
                bidder.check() == true : "bid:collection capability must be linked"
                refund.check() == true : "bid:refund capability must be linked"
                ftVault.isInstance(self.bidVaultType) : "bid:bid is not the requested fungible token"
                ftVault.balance >= self.livePrice! * 1.05 : "bid:too low bid"
            }

            let bidderRef = bidder.borrow() ?? panic("bid:could not borrow a reference for the bidders capability")
            assert(bidderRef.isInstance(self.underlyingType), message: "bid:bidder's collection capability does not match the vault")

            let refundRef = refund.borrow() ?? panic("bid:could not borrow a reference from the refund capability")
            assert(refundRef.isInstance(self.bidVaultType), message: "bid:refund capability is not the requested token")
            
            //Add block height checks
            //900 is 15 minutes in seconds (for timestamp calculations)
            if self.auctionEnd! - getCurrentBlock().timestamp <= 900.0 {
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
            emit Bid(buyer: self.winning!.address, price: self.livePrice!, auctionEnd: self.auctionEnd!)
        }

        pub fun end() {
            pre {
                self.auctionState == State.live : "end:vault has already closed"
                getCurrentBlock().timestamp >= self.auctionEnd! : "end:auction live"
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

            if FractionalVault.feeReceiver != nil {
                self.sendFungibleToken(to: FractionalVault.feeReceiver!, value: (self.livePrice! * 0.025))
            }

            emit Won(buyer: self.winning!.address, price: self.livePrice!, ids: keys)
        }

        /// @notice  function to burn all fractions and receive the underlying
        pub fun redeem(collection: &Fraction.Collection, amount: UInt256, redeemer: Capability<&{NonFungibleToken.CollectionPublic}>) {
            pre {
                self.auctionState == State.inactive : "redeem:no redeeming"
                redeemer.check() == true : "redeem:redeemer's collection capability must be linked"
                collection.vaultToFractions[self.id]!.length() == self.redemptionAmount : "redeem:collection does not contain all fractions"
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

            self.redemptionAmount = self.redemptionAmount - amount
            
            if self.redemptionAmount == 0 {

                let redeemersCollection = redeemer.borrow() ?? panic("redeem:could not borrow a reference to the redeemer's collection capability")

                //transfer NFTs to the owner of the fractions
                let keys = self.underlying.getIDs()
                for key in keys {
                    redeemersCollection.deposit(token: <- self.underlying.withdraw(withdrawID: key))
                }

                self.auctionState = State.redeemed

                emit Redeem(redeemer: redeemer.address, ids: keys)
            }
        }

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

            emit Cash(owner: collector.address, amount: share)
        }

        //Resource destruction
        //Add more logic behind conditions before a vault and other resources are destructed
        destroy() {
            pre {
                self.auctionState == FractionalVault.State.redeemed || self.auctionState == FractionalVault.State.ended : "destroy:invalid status for destroying vault"
                self.underlying.getIDs().length == 0 : "destroy:underlying contains NFTs"
                self.bidVault.balance == 0.0 : "destroy:bidVault balance is not empty"
                self.fractions.getIDs().length == 0 : "destroy:fractions have not been fully cashed or redeemed"
            }
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

    //Emmited when a vault gets added to the vault collection
    pub event VaultDeposited(id: UInt256)

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

            emit VaultDeposited(id: id)

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
        maxSupply: UInt256,
        medias: {UInt64: Media},
        displays: {UInt64: Display}
    ) {
        
        log("Curator: ")
        log(curator)

        let fractionalCollection = curator.borrow() ?? panic("could not borrow curators fractions")

        let fractionIds = fractionalCollection.getIDs()

        log("Fraction IDs: ")
        log(fractionIds)
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
            displays: displays
        )
        
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

        assert(vault.curator.address == curator.address, message: "this address is not permitted to mint f ractions to this vault")
        
        //mint the fractions
        let fractions <- Fraction.mintFractions(
            amount: 100, 
            vaultId: self.vaultCount - 1
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

        self.VaultPublicPath = /public/fractionalVault
        self.VaultStoragePath = /storage/fractionalVault
        self.AdministratorStoragePath = /storage/fractionalVaultAdmin

        self.vaultAddress = vaultAddress
        self.vaultCount = 0
        self.feeReceiver = nil

        let admin <- create Administrator()
        self.account.save(<- admin, to: self.AdministratorStoragePath)
        self.account.save<@FractionalVault.VaultCollection>(<- FractionalVault.createEmptyCollection(), to: FractionalVault.VaultStoragePath)
		self.account.link<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath, target: FractionalVault.VaultStoragePath)

        emit ContractInitialized()
    }
}
 