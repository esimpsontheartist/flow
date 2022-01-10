import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import EnumerableSet from "./EnumerableSet.cdc"
import CoreVault from "./CoreVault.cdc"
import Modules from "./Modules.cdc"
import Fraction from "./Fraction.cdc"
import Utils from "./Utils.cdc"
import Clock from "./Clock.cdc"

/////////////////////////////////////////
/// Fractional V1 NFT Vault contract ///
////////////////////////////////////////

pub contract FractionalVault {

    /// -----------------------------------
    /// ----------- Factory ---------------
    /// -----------------------------------

    /// @notice the number of NFT vaults
    pub var vaultCount: UInt256

    /// @notice the address where the vaults get minted to (address that has it's keys revoked)
    /// The address must contain the BurnerCollection Capability
    priv var burnerAddress: Address

    pub let VaultStoragePath: StoragePath
	pub let VaultPublicPath: PublicPath
    pub let MinterPrivatePath: PrivatePath
    pub let AdministratorStoragePath: StoragePath

    pub event ContractInitialized()

    pub var feeReceiver: Capability<&{FungibleToken.Receiver}>?

    pub resource Administrator {
        access(account) fun setBurnerAddress(address: Address) {
            FractionalVault.burnerAddress = address
        }
        access(account) fun setFeeReceiver(receiver: Capability<&{FungibleToken.Receiver}>) {
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

    /// -----------------------------------
    /// ------ Vault Events ---------------
    /// -----------------------------------
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
    pub event Cash(owner: Address, amount: UFix64, ids: [UInt64]);
    // @notice An envet emitted when a FractionalVault.Vault gets initiated
    pub event VaultInitiated(
        curator: Address,
        bidVaultType: Type,
        underlyingType: Type,
        maxSupply: UInt256,
    );

    //Struct used for function returns
    pub struct ReserveInfo {
        pub var voting: UInt256
        pub var reserve: UFix64

        init(_ voting: UInt256, _ reserve: UFix64){
            self.voting = voting
            self.reserve = reserve
        }
    }

    // Auction mappings
    priv let prices: {UInt64: EnumerableSet.UFix64Set}
    priv let priceToCount: {UInt64: {UFix64: UInt256}}
    priv let userPrices: {UInt64: {Address: UFix64}}

    // Reserve Price Functions
    access(account) fun addToPrice(_ vaultId: UInt64, _ amount: UInt256, _ price: UFix64) {
        if self.prices[vaultId] == nil {
            self.prices.insert(key: vaultId, EnumerableSet.UFix64Set())
        }

        let nested = self.priceToCount[vaultId] ?? {}
        //forcing optional value below leads to an error
        if nested[price] == nil {
            nested[price] = amount
        } 
        else {
            nested[price] = nested[price]! + amount
        }
        
        self.priceToCount[vaultId] = nested

        if self.priceToCount[vaultId]![price]! * 100 >= Fraction.fractionSupply[vaultId]! && !self.prices[vaultId]!.contains(price) {
            self.prices[vaultId]!.add(price)
        }
    }   

    access(account) fun removeFromPrice(_ vaultId: UInt64, _ amount: UInt256, _ oldPrice: UFix64) {
        let nested = self.priceToCount[vaultId] ?? {}
        
        if nested[oldPrice] == nil {
            nested[oldPrice] = amount
        } 
        else {
            nested[oldPrice] = nested[oldPrice]! - amount
        }

        self.priceToCount[vaultId] = nested

        if self.prices[vaultId] == nil {
            return
        }

        if self.priceToCount[vaultId]![oldPrice]! * 100 < Fraction.fractionSupply[vaultId]! && self.prices[vaultId]!.contains(oldPrice) {
            self.prices[vaultId]!.remove(oldPrice)
        }
    }

    pub fun reservePrice(_ vaultId: UInt64): ReserveInfo {

        var tempPrices: [UFix64]? = self.prices[vaultId]?.values()
        if tempPrices == nil {
            tempPrices = []
        }
        tempPrices = Utils.sort(tempPrices!)
        var voting: UInt256 = 0
        var x: Int = 0
        while x < tempPrices!.length {   
            if tempPrices![x] != nil {
                voting = voting + self.priceToCount[vaultId]![tempPrices![x]]!
            }
            x = x + 1
        }

        var reserve = 0.0 
        var count: UInt256 = 0
        var y = 0
        while y < tempPrices!.length {
            if tempPrices![y] != nil {
                count = count + self.priceToCount[vaultId]![tempPrices![y]]!
            }
            if count * 2 >= voting {
                reserve = tempPrices![y]
                break
            }
        }
        
        return ReserveInfo(voting, reserve)
    }

    pub struct VaultHook: Fraction.Hook {
        //Used for deposits/withdrawals
        access(account) fun beforeTransfer(
            from: Address?, 
            to: Address?, 
            amount: UInt256, 
            vaultId: UInt64
        ){
            //On deposit
            if from == nil && to != nil {
                FractionalVault.addToPrice(vaultId, amount, FractionalVault.userPrices[vaultId]![to!]!)
            //On withdraw    
            } else if to == nil && from != nil {
                FractionalVault.removeFromPrice(vaultId, amount, FractionalVault.userPrices[vaultId]![from!]!)
            }
        }

        access(account) fun onBurn(
            from: Address?,
			amount: UInt256, 
			vaultId: UInt64
		){
            FractionalVault.removeFromPrice(vaultId, amount, FractionalVault.userPrices[vaultId]![from!]!)
        }
    }
    
    pub resource interface PublicVault {
        pub fun updateUserPrice(collection: &Fraction.BulkCollection, amount: UInt256, new: UFix64)
        pub fun isLivePrice(price: UFix64): Bool
        pub fun borrowUnderlying(): &{NonFungibleToken.CollectionPublic}
        pub fun vaultBalance(): &{FungibleToken.Balance}
        pub fun start(
            ftVault: @FungibleToken.Vault, 
            refund: Capability<&{FungibleToken.Receiver}>,
            bidder: Capability<&{NonFungibleToken.CollectionPublic}>
        )
        pub fun bid(
            ftVault: @FungibleToken.Vault, 
            refund: Capability<&{FungibleToken.Receiver}>,
            bidder: Capability<&{NonFungibleToken.CollectionPublic}>
        )
        pub fun end()
        pub fun redeem(collection: &Fraction.BulkCollection, amount: UInt256, redeemer: Capability<&{NonFungibleToken.CollectionPublic}>)
        pub fun cash(collection: &Fraction.BulkCollection, collector: Capability<&{FungibleToken.Receiver}>)
        access(account) fun borrowUnderlyingRef(id: UInt64): auth &NonFungibleToken.NFT
    }

    //Restrict the vault resource with an interface
    pub resource Vault: PublicVault, Modules.CappedMinter {
        //Main resources
        access(contract) var vault: @CoreVault.Vault
        //The vault that holds fungible tokens for an auction
        access(contract) let bidVault: @FungibleToken.Vault
        //The type of Fungible Token that the vault accepts
        pub let bidVaultType: Type

        pub let maxSupply: UInt256

        // Auction information// 
        pub var auctionEnd: UFix64?
        pub var auctionLength: UFix64
        pub var livePrice: UFix64?
        pub var winning: Capability<&{NonFungibleToken.CollectionPublic}>?
        pub var refundCapability: Capability<&{FungibleToken.Receiver}>?
        pub var auctionState: State?

        init(
            vault: @CoreVault.Vault,
            bidVault: @FungibleToken.Vault,
            bidVaultType: Type,
            maxSupply: UInt256,
        ) {
            pre {
                vault.underlying.getIDs().length > 0 : "init:vault provided holds no NFTs"
            }

            post {
                maxSupply >= 1000 : "init:max supply cannot be less than 1000"
            }
            
            self.vault <- vault
            self.bidVault <- bidVault
            self.bidVaultType = bidVaultType
            self.auctionLength = 172800.0 //2 days in seconds 
            self.auctionState = State.inactive
            self.maxSupply = maxSupply
            self.auctionEnd = nil
            self.livePrice = nil
            self.winning = nil
            self.refundCapability = nil
            
            Fraction.hooks[self.vault.uuid] = FractionalVault.VaultHook()

            emit VaultInitiated(
                curator: self.vault.curator.address,
                bidVaultType: bidVaultType,
                underlyingType: self.vault.underlyingType,
                maxSupply: maxSupply
            )
        }

        pub fun updateUserPrice(collection: &Fraction.BulkCollection, amount: UInt256, new: UFix64) {
        
            let fractionsOwner = collection.owner?.address!

            let fractionIds = collection.getIDsByVault(vaultId: self.vault.uuid)

            if fractionIds.length == 0 {
                return
            }

            let balance = UInt256(fractionIds.length)

            FractionalVault.addToPrice(self.vault.uuid, balance, new)
            FractionalVault.removeFromPrice(self.vault.uuid, balance, FractionalVault.userPrices[self.vault.uuid]![fractionsOwner]!)

            let nested = FractionalVault.userPrices[self.vault.uuid] ?? {}
            nested[fractionsOwner] = new
            FractionalVault.userPrices[self.vault.uuid] = nested
            emit PriceUpdate(fractionsOwner: fractionsOwner, amount: amount, price: new)
        }

        pub fun isLivePrice(price: UFix64): Bool {
            return FractionalVault.prices[self.vault.uuid]!.contains(price);
        }

        // function to borrow a reference to the underlying collection
        // can be used to deposit to the vault
        pub fun borrowUnderlying(): &{NonFungibleToken.CollectionPublic} {
            return self.vault.borrowPublicCollection()
        }

        // function to get an auth reference to a given NFT, which can be upcasted to the original Type
        access(account) fun borrowUnderlyingRef(id: UInt64): auth &NonFungibleToken.NFT {
            return self.vault.ref(id: id)
        }

        pub fun vaultBalance(): &{FungibleToken.Balance} {
            return &self.bidVault as &{FungibleToken.Balance}
        }

        access(self) fun sendFungibleToken(to: Capability<&{FungibleToken.Receiver}>, value: UFix64) {
            //borrow a capability for the vault of the 'to' address
            let toVault = to.borrow() ?? panic("Could not borrow a reference to the account receiver")
            //withdraw 'value' from the bidVault
            toVault.deposit(from: <- self.bidVault.withdraw(amount: value))
        }

        /// @notice the function to mint a new vault
        /// @param collection the collection for the underlying set of NFTS
        /// @return the ID of the vault
        pub fun mint(
            amount: UInt256,
        ): @Fraction.Collection
        {   
            pre {
                Fraction.fractionSupply[self.vault.uuid]! + amount <= self.maxSupply : "mint:minting amount will exceed totalSupply"
            }
            //mint the fractions
            let fractions <- Fraction.mintFractions(
                amount: 100, 
                vaultId: self.vault.uuid
            )
            
            //return the fractions
            return <- fractions
        }
        
        /// @notice kick off an auction. Must send reservePrice in the correct Fungible Token
        pub fun start(
            ftVault: @FungibleToken.Vault, 
            refund: Capability<&{FungibleToken.Receiver}>,
            bidder: Capability<&{NonFungibleToken.CollectionPublic}>
        ) {
            pre {
                self.auctionState == State.inactive : "start:no auction starts"
                FractionalVault.reservePrice(self.vault.uuid).voting * 2 >= Fraction.fractionSupply[self.vault.uuid]! : "start:not enough voters"
                bidder.check() == true : "start:collection capability must be linked"
                refund.check() == true : "start:refund capability must be linked"
                ftVault.isInstance(self.bidVaultType) : "start:bid is not the requested fungible token"
                ftVault.balance >= FractionalVault.reservePrice(self.vault.uuid).reserve : "start:too low bid"
            } 

            let bidderRef= bidder.borrow() ?? panic("start:could not borrow a reference from the bidders capability")
            assert(bidderRef.isInstance(self.vault.underlyingType), message: "start:bidder's collection capability does not match the vault")

            let refundRef = refund.borrow() ?? panic("start:could not borrow a reference from the refund capability")
            assert(refundRef.isInstance(self.bidVaultType), message: "start:refund capability is not the requested token")

            self.auctionEnd = Clock.time() + self.auctionLength
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
                Clock.time() < self.auctionEnd! : "bid:auction end"
                bidder.check() == true : "bid:collection capability must be linked"
                refund.check() == true : "bid:refund capability must be linked"
                ftVault.isInstance(self.bidVaultType) : "bid:bid is not the requested fungible token"
                ftVault.balance >= self.livePrice! * 1.05 : "bid:too low bid"
            }

            let bidderRef = bidder.borrow() ?? panic("bid:could not borrow a reference for the bidders capability")
            assert(bidderRef.isInstance(self.vault.underlyingType), message: "bid:bidder's collection capability does not match the vault")

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
            emit Bid(buyer: self.winning!.address, price: self.livePrice!, auctionEnd: self.auctionEnd!)
        }

        pub fun end() {
            pre {
                self.auctionState == State.live : "end:vault has already closed"
                Clock.time() >= self.auctionEnd! : "end:auction live"
            }
            
            //get capabilit of the winners collection
            let winnersCollection = self.winning!.borrow() ?? panic("Auction winner does not have a capability to receive the underlying")

            // transfer NFT to winner
            let collection <- self.vault.end()
            let keys = collection.getIDs()
            for key in keys {
                winnersCollection.deposit(token: <- collection.withdraw(withdrawID: key))
            }
            destroy collection
            //change auction state
            self.auctionState = State.ended

            if FractionalVault.feeReceiver != nil {
                self.sendFungibleToken(to: FractionalVault.feeReceiver!, value: (self.livePrice! * 0.025))
            }

            emit Won(buyer: self.winning!.address, price: self.livePrice!, ids: keys)
        }

        /// @notice  function to burn all fractions and receive the underlying
        pub fun redeem(collection: &Fraction.BulkCollection, amount: UInt256, redeemer: Capability<&{NonFungibleToken.CollectionPublic}>) {
            pre {
                self.auctionState == State.inactive : "redeem:no redeeming"
                redeemer.check() == true : "redeem:redeemer's collection capability must be linked"
                Fraction.fractionSupply[self.vault.uuid]! > 0 : "redeem:fraction supply is not greater than 0"
                UInt256(collection.getIDsByVault(vaultId: self.vault.uuid).length) == Fraction.fractionSupply[self.vault.uuid] : "redeem:collection does not contain all fractions"
            }

            let bidderRef = redeemer.borrow() ?? panic("redeem:could not borrow a reference for the bidders capability")
            assert(bidderRef.isInstance(self.vault.underlyingType), message: "redeem:bidder's collection capability does not match the vault")
            
            let fractionCollection <- collection.withdrawCollection(vaultId: self.vault.uuid)
            let collectionAmount = UInt256(fractionCollection.getIDs().length)
            Fraction.fractionSupply[self.vault.uuid] = Fraction.fractionSupply[self.vault.uuid]! - collectionAmount

            //Push the fraction collection to the array
            let burner = getAccount(FractionalVault.burnerAddress).getCapability<&Fraction.BurnerCollection>(Fraction.BurnerPath).borrow() 
            ?? panic("Could not borrow a reference to the Fractional Vault Collection")

            //"retire" the fractions
            burner.retire(<- fractionCollection)
            let redeemersCollection = redeemer.borrow() ?? panic("redeem:could not borrow a reference to the redeemer's collection capability")

            //transfer NFTs to the owner of the fractions
            let collection <- self.vault.end()
            let ids = collection.getIDs()
            for id in ids {
                redeemersCollection.deposit(token: <- collection.withdraw(withdrawID: id))
            }
            destroy collection

            self.auctionState = State.redeemed

            emit Redeem(redeemer: redeemer.address, ids: ids)
            
        }

        pub fun cash(collection: &Fraction.BulkCollection, collector: Capability<&{FungibleToken.Receiver}>) {
            pre {
                self.auctionState == State.ended : "cash:vault not closed yet"
                collection.getIDsByVault(vaultId: self.vault.uuid).length != 0 : "cash:collection does not contain fractions for this vault"
                collector.check() == true : "cash:collector capability is not linked"
            }
            
            let collectorRef = collector.borrow() 
            ?? panic("cash:could not borrow a reference from the collector's fungible token capability")
            assert(collectorRef.isInstance(self.bidVaultType), message: "cash:collector's capability is not the requested type")

            let fractions <- collection.withdrawCollection(vaultId: self.vault.uuid)

            //calculate share of the total fraction supply for the vault (Need to check the math)
            var share = (UFix64(fractions.getIDs().length) * self.bidVault.balance) / UFix64(Fraction.fractionSupply[self.vault.uuid]!)

            //Remove fractions from supply 
            Fraction.fractionSupply[self.vault.uuid] = Fraction.fractionSupply[self.vault.uuid]! - UInt256(fractions.getIDs().length)
            //Push the fraction collection to the array
            let burner = getAccount(FractionalVault.burnerAddress).getCapability<&Fraction.BurnerCollection>(Fraction.BurnerPath).borrow() 
            ?? panic("Could not borrow a reference to the Fractional Vault Collection")

            let ids = fractions.getIDs()
            //"retire" the fractions
            burner.retire(<- fractions)
           
            //sendFlow
            self.sendFungibleToken(to: collector, value: share)

            emit Cash(owner: collector.address, amount: share, ids: ids)
        }

        pub fun withdrawVault(): @CoreVault.Vault {
            pre {
                self.auctionState == FractionalVault.State.inactive : "withdrawVault:cannot withdraw from an active state"
            }
            //This should never get triggered
            post {
                result.underlying.getIDs().length != 0 : "withdrawVault:returned a vault with an empty underlying collection"
            }

            let emptyCollection <- Fraction.createEmptyCollection()
            var vault <- CoreVault.mintVault(
                curator: self.vault.curator, 
                underlying: <- emptyCollection, 
                underlyingType: Type<@AnyResource>(),
                name: nil,
                description: nil
            )

            //remove the hook from the fractions
            Fraction.hooks[self.vault.uuid] = nil

            self.vault <-> vault
            return <- vault
        }

        destroy() {
            pre {
                self.auctionState == FractionalVault.State.redeemed || self.auctionState == FractionalVault.State.ended : "destroy:invalid status for destroying vault"
                self.bidVault.balance == 0.0 : "destroy:bidVault balance is not empty"
            }
            destroy self.vault
            destroy self.bidVault
        }

    }

    pub resource interface VaultCollectionPublic {
        pub fun depositVault(vault: @FractionalVault.Vault)
		pub fun getIDs(): [UInt64]
		pub fun borrowVault(id: UInt64): &{FractionalVault.PublicVault}?
    }

    //Emmited when a vault gets added to the vault collection
    pub event VaultDeposited(id: UInt64, to: Address?)
    pub event VaultWithdrawn(id: UInt64, from: Address?)

    //A way for an account to store multiple FractionalVaults
    //It intentionally does not include
    pub resource VaultCollection: VaultCollectionPublic, Modules.CappedMinterCollection {
        //dictionary of Vault conforming resources
        //Vault is a resource type with a `UInt256` ID field
        pub var vaults: @{UInt64: FractionalVault.Vault}

        init() {
            self.vaults <- {}
        }

        // takes a vault and adds it to the vault dictionary
        pub fun depositVault(vault: @FractionalVault.Vault) {
            let vault <- vault 

            let id: UInt64 = vault.uuid

            emit VaultDeposited(id: id, to: self.owner?.address)

            let oldVault <- self.vaults[id] <- vault

            //add event depositing a vault

            destroy oldVault
        }

        pub fun withdrawVault(id : UInt64): @FractionalVault.Vault {
            let vault <- self.vaults.remove(key: id) ?? panic("withdrawVault:no vault with given id")
            emit VaultWithdrawn(id: vault.uuid, from: self.owner?.address)
            return <- vault
        }

        pub fun getIDs(): [UInt64] {
            return self.vaults.keys
        }

        // borrowVaultgets a reference to a Vault in the collection
		// so that the caller can read its metadata and call its methods
        pub fun borrowVault(id: UInt64): &{FractionalVault.PublicVault}? {
            if self.vaults[id] != nil {
                let ref = &self.vaults[id] as &{FractionalVault.PublicVault}
                return ref 
            } else {
                return nil
            }
        }
        
        pub fun borrowMinter(id: UInt64): &{Modules.CappedMinter}? {
            if self.vaults[id] != nil {
                let ref = &self.vaults[id] as &{Modules.CappedMinter}
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
        vault: @CoreVault.Vault,
        bidVault: @FungibleToken.Vault,
        bidVaultType: Type,
        maxSupply: UInt256,
    ) {

        //Initialize a vault
        let fractionalVault <- create Vault(
            vault: <- vault,
            bidVault: <- bidVault, 
            bidVaultType: bidVaultType,
            maxSupply: maxSupply
        )
        
        let vaultCollection = getAccount(fractionalVault.vault.curator.address).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
        ?? panic("Could not borrow a reference to the Fractional Vault Collection")

        vaultCollection.depositVault(vault: <- fractionalVault)

        self.vaultCount =  self.vaultCount + 1
    }

    init(burnerAddress: Address) {

        self.VaultPublicPath = /public/fractionalVault
        self.VaultStoragePath = /storage/fractionalVault
        self.MinterPrivatePath = /private/fractionalVault
        self.AdministratorStoragePath = /storage/fractionalVaultAdmin

        self.burnerAddress = burnerAddress
        self.vaultCount = 0
        self.feeReceiver = nil
        self.prices = {}
        self.priceToCount = {}
        self.userPrices = {}

        let admin <- create Administrator()
        self.account.save(<- admin, to: self.AdministratorStoragePath)
        self.account.save<@FractionalVault.VaultCollection>(<- FractionalVault.createEmptyCollection(), to: FractionalVault.VaultStoragePath)
		self.account.link<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath, target: FractionalVault.VaultStoragePath)
        self.account.link<&{Modules.CappedMinterCollection}>(FractionalVault.MinterPrivatePath, target: Fraction.CollectionStoragePath)

        emit ContractInitialized()
    }
}
 