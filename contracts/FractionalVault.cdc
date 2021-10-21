import FungibleToken from "./standard/FungibleToken.cdc"
import FlowToken from "./standard/FlowToken.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"
import EnumerableSet from "./lib/EnumerableSet.cdc"
import WrappedCollection from "./lib/WrappedCollection.cdc"
import PriceBook from "./PriceBook.cdc"
import Fraction from "./Fraction.cdc"

/////////////////////////////////////
// Fractional NFT Vault contract ///
////////////////////////////////////

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

     //Vault settings (NEEDS A CLEANUP)
    pub struct Settings {
        pub var maxAuctionLength: UFix64
        pub var minAuctionLength: UFix64
        pub var minBidIncrease: UFix64
        pub let maxMinBidIncrease: UFix64 //10% bid increase is the max
        pub let minMinBidIncrease: UFix64 //1% is the bid increase min
        pub var minVotePercentage: UFix64 //Percentage of tokens required to be voting for an auction to start
        pub var maxReserveFactor: UFix64 // the max % increase over the initial
        pub var minReserveFactor: UFix64 // the max % decreaseFactor from the initial
        pub var feeReceiver: Address? // the address that receives auction fees

            //need to set the right initial values
            init() {
            self.maxAuctionLength =  0.0
            self.minAuctionLength = 0.0
            self.minBidIncrease = 0.0
            self.maxMinBidIncrease = 0.0
            self.minMinBidIncrease = 0.0
            self.minVotePercentage = 0.0
            self.maxReserveFactor = 0.0
            self.minReserveFactor = 0.0
            self.feeReceiver = nil
        }

        access(account) fun setMaxAuctionLength(length: UFix64) {

            pre {
                //length <= 8 weeks in UFix64?
                length > self.minAuctionLength: "max auction length too low"
            }

            emit UpdateMaxAuctionLength(old: self.maxAuctionLength, new: length)
            self.maxAuctionLength = length
        }

        access(account) fun setMinAuctionLength(length: UFix64) {
            //require -> pre (or 'precondition') in Cadence
            pre {
                //length => 1 day in UFix64?
                length < self.maxAuctionLength: "max auction length too high"
            }

            emit UpdateMinAuctionLength(old: self.minAuctionLength, new: length)
            self.minAuctionLength = length
        }

        access(account) fun setMinBidIncrease(min: UFix64) {
            pre {
                min <= self.maxMinBidIncrease: "min bid increase too high"
                min >= self.minMinBidIncrease: "min bid increase too low"
            }

            emit UpdateMinBidIncrease(old: self.minBidIncrease, new: min)
            self.minBidIncrease = min
        }

        access(account) fun setMinVotePercentage(min: UFix64) {
            pre { 
                // Need to find the right way to represent percentage in Flow
                min <= 100.0: "min vote percentage too high"
            }

            emit UpdateMinVotePercentage(old: self.minVotePercentage, new: min)
            self.minVotePercentage = min
        }

        access(account) fun setMaxReserveFactor(factor: UFix64) {
            pre {
                factor > self.minReserveFactor: "max reserve factor too low"
            }

            emit UpdateMaxReserveFactor(old: self.maxReserveFactor, new: factor)
            self.maxReserveFactor = factor
        }

        access(account) fun setMinReserveFactor(factor: UFix64) {
            pre {
                factor < self.maxReserveFactor: "min reserve factor too high"
            }

            emit UpdateMinReserveFactor(old: self.minReserveFactor, new: factor)
            self.minReserveFactor = factor
        }

        access(account) fun setFeeReceiver(receiver: Address) {
            //Research: what is the 0 address in Cadence?
            pre {
                receiver != 0x0: "fees cannot go to 0 address"
            }
            emit UpdateFeeReceiver(old: self.feeReceiver!, new: receiver)
            self.feeReceiver = receiver
        }

    }

    /// @notice a settings constant controlled by governance
    access(account) let settings: Settings

    //Vault settings Events
    pub event UpdateMaxAuctionLength(old: UFix64, new: UFix64)
    pub event UpdateMinAuctionLength(old: UFix64, new: UFix64)
    pub event UpdateMinBidIncrease(old: UFix64, new: UFix64)
    pub event UpdateMinVotePercentage(old: UFix64, new: UFix64)
    pub event UpdateMaxReserveFactor(old: UFix64, new: UFix64)
    pub event UpdateMinReserveFactor(old: UFix64, new: UFix64)
    pub event UpdateFeeReceiver(old: Address, new: Address)

    //enum for auction state
    pub enum State: UInt8 {
        pub case inactive
        pub case live
        pub case ended
        pub case redeemed
    }

    /// -----------------------------------
    /// ------ Vault Events ---------------
    /// -----------------------------------
    //@reserach: is there a concept in Cadence/Flow similar to 'indexed'
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
    pub event Initialized(id: UInt256)

    //check that the argument is the right type of capbility (restriced vs non-restriced)
    pub fun updateFractionPrice(_ vaultId: UInt256, collection: &Fraction.Collection, new: UFix64) {

        let fractionsOwner = collection.owner?.address!

        let fractionIds = collection.vaultToFractions[vaultId]!.values()

        if fractionIds.length == 0 {
            return
        }

        PriceBook.addToPrice(vaultId, collection.vaultToFractions[vaultId]!.length(), new)

        //Update the price for fractionsPrices and remove old prices
        for id in fractionIds {
            let fraction = collection.borrowFraction(id: id)
            let uuid = fraction!.uuid
            PriceBook.removeFromPrice(vaultId, 1, PriceBook.fractionPrices[vaultId]![uuid]!)
            let nested = PriceBook.fractionPrices[vaultId] ?? {}
            nested[uuid] = new
            PriceBook.fractionPrices[vaultId] = nested
        }
        
        emit PriceUpdate(fractionsOwner: fractionsOwner, price: new)
    }

    pub resource Vault {

        pub let id: UInt256

        //expose all these things through functions
        access(account) let settings: Settings

        //The vault that holds fungible tokens for an auction
        access(account) let bidVault: @FungibleToken.Vault
        //The collection for the fractions
        access(account) var fractions: @Fraction.Collection
        //Collection of the NFTs the user will fractionalize (UInt64 is meant to be the NFT's uuid)
        //change access control later
        access(account) var underlying: @WrappedCollection.Collection

        // Auction information// 
        pub var auctionEnd: UFix64?
        pub var auctionLength: UFix64
        pub var livePrice: UFix64?
        pub var winning: Address?
        pub var auctionState: State?

        init(
            id: UInt256,
        ) {
            self.id = id
            self.settings = FractionalVault.settings
            self.auctionLength = 172800.0 //2 days in seconds 
            self.auctionState = State.inactive
            
            // Resources
            self.bidVault <- FlowToken.createEmptyVault()
            self.fractions <- Fraction.createEmptyFractionCollection()
            self.underlying <- WrappedCollection.createEmptyCollection()

            //optional nil variables
            self.auctionEnd = nil
            self.livePrice = nil
            self.winning = nil
            
            emit Initialized(id: id)
        }
        
        pub fun isLivePrice(price: UFix64): Bool {
            return PriceBook.prices[self.id]!.contains(price);
        }

        // function to borrow a reference to the underlying collection
        pub fun borrowUnderlying(): &{WrappedCollection.WrappedCollectionPublic} {
            return &self.underlying as &{WrappedCollection.WrappedCollectionPublic}
        }

        pub fun borrowBidVault(): &{FungibleToken.Balance} {
            return &self.bidVault as &{FungibleToken.Balance}
        }

        pub fun borrowCollection() : &{Fraction.CollectionPublic} {
            return &self.fractions as! auth &{Fraction.CollectionPublic}
        }

        access(contract) fun sendFlow(to: Address, value: UFix64) {
            //borrow a capability for the vault of the 'to' address
            let toVault = getAccount(to).getCapability<&FlowToken.Vault>(/public/flowTokenVault).borrow() ?? panic("Could not borrow a reference to the account receiver")
            //withdraw 'value' from the bidVault
            toVault.deposit(from: <- self.bidVault.withdraw(amount: value))
        }
        

        /// @notice kick off an auction. Must send reservePrice in FLOW
        pub fun start(_ flowVault: @FungibleToken.Vault) {
            pre {
                self.auctionState == State.inactive : "start:no auction starts"
                flowVault.balance >= PriceBook.reservePrice(self.id).reserve : "start:too low bid"
                PriceBook.reservePrice(self.id).voting * 2 >= Fraction.fractionSupply[self.id]! : "start:not enough voters"
            }

            self.auctionEnd = getCurrentBlock().timestamp + self.auctionLength
            self.auctionState = State.live

            self.livePrice = flowVault.balance
            self.winning = flowVault.owner?.address

            //Deposit the bid into the vault
            self.bidVault.deposit(from: <-flowVault)

            emit Start(buyer: self.winning!, price: self.livePrice!) 
        }

        pub fun bid(_ flowVault: @FungibleToken.Vault) {
            pre {
                self.auctionState == State.inactive : "bid:no auction starts"
                flowVault.balance * 100.0 >= self.livePrice! * 105.0 : "bid:too low bid"
                getCurrentBlock().timestamp < self.auctionEnd! : "bid:auction end"
            }

            //900 is 15 minutes in seconds (for timestamp calculations)
            if self.auctionEnd! - getCurrentBlock().timestamp <= 900.0 {
                self.auctionEnd = self.auctionEnd! + 900.0
            }
            
            //refund the last bidder
            self.sendFlow(to: self.winning!, value: self.livePrice!);
            
            self.livePrice = flowVault.balance
            self.winning = flowVault.owner?.address

            emit Bid(buyer: flowVault.owner?.address!, price: flowVault.balance)

            destroy flowVault
        }

        pub fun end() {
            pre {
                self.auctionState == State.live : "end:vault has already closed"
                getCurrentBlock().timestamp >= self.auctionEnd! : "end:auction live"
            }
            
            //get capabilit of the winners collection
            let collection = getAccount(self.winning!).getCapability(WrappedCollection.WrappedCollectionPublicPath).borrow<&{WrappedCollection.WrappedCollectionPublic}>() ?? panic("Could not borrow a reference to the account receiver")

            // transfer NFT to winner
            let keys = self.underlying.getIDs()
            for key in keys {
                collection.deposit(token: <- self.underlying.withdraw(withdrawID: key))
            }
            //change auction state
            self.auctionState = State.ended

            if self.settings.feeReceiver != nil {
                self.sendFlow(to: self.settings.feeReceiver!, value: (self.livePrice! / 40.0))
            }

            emit Won(buyer: self.winning!, price: self.livePrice!)
        }

        /// @notice an external function to burn all fractions and receive the underlying
        pub fun redeem(_ collection: @NonFungibleToken.Collection) {
            pre {
                self.auctionState == State.inactive : "redeem:no redeeming"
            }

            let fractions <- collection as! @Fraction.Collection

            assert(fractions.balance() == Fraction.fractionSupply[self.id]!, message: "redeem:collection does not contain all fractions")

            let fractionsOwner = fractions.owner?.address!

            //burn fractions
            destroy fractions

            //get capabilit of the winners collection
            let collection = getAccount(fractionsOwner).getCapability(WrappedCollection.WrappedCollectionPublicPath).borrow<&{WrappedCollection.WrappedCollectionPublic}>() ?? panic("Could not borrow a reference to the account receiver")

            //transfer NFTs to the owner of the fractions
            let keys = self.underlying.getIDs()
            for key in keys {
                collection.deposit(token: <- self.underlying.withdraw(withdrawID: key))
            }

            self.auctionState = State.redeemed

            emit Redeem(redeemer: fractionsOwner)
        }

        pub fun cash(_ collection: @NonFungibleToken.Collection) {
            pre {
                self.auctionState == State.ended : "cash:vault not closed yet"
                
            }

            let fractions <- collection as! @Fraction.Collection

            assert(fractions.balance() > 0, message: "cash:no tokens to cash out")

            let fractionsOwner = fractions.owner?.address!
            //calculate share of the total fraction supply for the vault (Need to check the math)
            var share = (UFix64(fractions.balance()) * self.bidVault.balance) / UFix64(Fraction.fractionSupply[self.id]!)

            //burn the fractions
            destroy fractions

            //sendFlow
            self.sendFlow(to: fractionsOwner, value: share)

            emit Cash(owner: fractionsOwner, flow: share)
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
        //change to access(account), pub now to avoid linter errrors
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
    // CHANGE TO: access(account)
    pub fun createEmptyCollection(): @FractionalVault.VaultCollection {
        return <- create VaultCollection()
    }

    /// @notice the function to mint a new vault
    /// @param collection the collection for the underlying set of NFTS
    /// @return the ID of the vault
    // CHANGE: remove the return and just mint directly to the address that will hold the vault
    pub fun mint(collection: @WrappedCollection.Collection): @FractionalVault.Vault {

        var count = Fraction.count + 1
        //Initialize a vault
        let vault <- create Vault(id: Fraction.count)

        let collectionOwner = collection.owner!

        //mint the fractions
        let fractions <- Fraction.mintFractions(amount: 10000, vaultId: self.vaultCount)
        assert(count == Fraction.count, message : "mismatch")
        
        emit Mint(underlyingOwner: collectionOwner.address, vaultId: vault.id);

        //deposit the underlying NFTs to the Vault
        let keys = collection.getIDs()
        for key in keys {
            vault.underlying.deposit(token: <- collection.withdraw(withdrawID: key))
        }

        //capability to deposit fractions to the owner of the underlying NFT
        let fractionCapability = collectionOwner.getCapability(Fraction.CollectionPublicPath).borrow<&{Fraction.CollectionPublic}>() ?? panic("Could not borrow a reference to the account receiver")
        //Receive the underlying
        let fractionIds = fractions.getIDs()
        for key in fractionIds {
            fractionCapability.deposit(token: <- fractions.withdraw(withdrawID: key))
        }

        self.vaultCount =  self.vaultCount + 1
        
        //destroy the collection sent
        destroy collection
        //destroy the fraction resources since they have been moved
        destroy fractions
        //return the vault
        return <- vault
    }

    init(vaultAddress: Address) {
        self.vaultAddress = vaultAddress
        self.vaultCount = 0
        self.settings = Settings()

        self.VaultPublicPath = /public/fractionalVault
        self.VaultStoragePath = /storage/fractionalVault

        self.account.save<@FractionalVault.VaultCollection>(<- FractionalVault.createEmptyCollection(), to: FractionalVault.VaultStoragePath)
		self.account.link<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath, target: FractionalVault.VaultStoragePath)
    }
}
 