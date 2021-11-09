import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import WrappedCollection from "./WrappedCollection.cdc"
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

     //Vault settings (NEEDS A CLEANUP)
    pub struct Settings {
        pub var feeReceiver: Address? // the address that receives auction fees

            //need to set the right initial values
            init() {
            self.feeReceiver = nil
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
    pub fun updateFractionPrice(_ vaultId: UInt256, collection: &Fraction.Collection, amount: UInt256, new: UFix64) {

        let fractionsOwner = collection.owner?.address!

        //length is 0 for some reason
        let fractionIds = collection.vaultToFractions[vaultId]!.values()

        if fractionIds.length == 0 {
            emit PriceUpdate(fractionsOwner: fractionsOwner, price: 0.0)
            return
        }

        var i: UInt256 = 0
        let fractions: [UInt64] = []
        while i < amount {
            let value = fractionIds[i]
            fractions.append(value)
            i = i + 1
        }

        PriceBook.addToPrice(vaultId, UInt256(fractions.length), new)

        //Update the price for fractionsPrices and remove old prices
        for id in fractions {
            let fraction = collection.borrowFraction(id: id)
            let uuid = fraction!.uuid
            log("(PriceBook.fractionPrices[vaultId]")
            log(PriceBook.fractionPrices[vaultId])
            let nested = PriceBook.fractionPrices[vaultId] ?? {}
            log("nested: ")
            log(nested)
            log("nested length: ")
            log(nested.length)
            if nested[uuid] != nil {
                PriceBook.removeFromPrice(vaultId, 1, nested[uuid]!)
            }   
            nested[uuid] = new
            log("new")
            log(new)
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
        //The collection for the fractions
        access(contract) var fractions: @Fraction.Collection
        //Collection of the NFTs the user will fractionalize (UInt64 is meant to be the NFT's uuid)
        access(contract) var underlying: @WrappedCollection.Collection
        //address that can receive the fractions
        access(contract) var curator: Address?

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
            self.curator = nil
            
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

        pub fun getcurator(): Address? {
            return self.curator
        }

        access(contract) fun setCurator(_ curator: Address){
            self.curator = curator
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

        //Helper function that allows the minting function to rapidly
        //swap the old empty collection for
        access(contract) fun depositCollection(_ collection: @WrappedCollection.Collection){
            let oldCollection <- self.underlying <- collection
            destroy oldCollection
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
    pub fun mintVault(collection: @WrappedCollection.Collection, fractionCurator: Address) {

        
        //Initialize a vault
        let vault <- create Vault(id: self.vaultCount)

        //set fractions Curator
        vault.setCurator(fractionCurator)
        //collection must have an owner, otherwise this transaction will revert its execution
        let curator = getAccount(fractionCurator)
        
        emit Mint(underlyingOwner: curator.address, vaultId: vault.id);

        //deposit the underlying NFTs to the Vault
        vault.depositCollection(<- collection)
        
        let vaultCollection = getAccount(self.vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
        ?? panic("Could not borrow a reference to the Fractional Vault Collection")

        vaultCollection.depositVault(vault: <- vault)

        self.vaultCount =  self.vaultCount + 1
    }

    /// @notice the function to mint a new vault
    /// @param collection the collection for the underlying set of NFTS
    /// @return the ID of the vault
    //Change to access account before testnet deployment
    pub fun mintVaultFractions(vaultId: UInt256){
        
        //Get capability for the vault
        let vaultCollection = getAccount(self.vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
        ?? panic("Could not borrow a reference to the Fractional Vault Collection")

        let vault = vaultCollection.borrowVault(id: vaultId)

        //mint the fractions
        /**
         * Separate mint function into smaller cheaper functions
         */
        let fractions <- Fraction.mintFractions(amount: 100, vaultId: self.vaultCount - 1)

        //capability to deposit fractions to the owner of the underlying NFT
        let curator =  getAccount(vault!.curator!)
        let fractionCapability = curator.getCapability(Fraction.CollectionPublicPath).borrow<&{Fraction.CollectionPublic}>() 
        ?? panic("Could not borrow a reference to the account receiver")
        //Receive the underlying
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

        self.VaultPublicPath = /public/fractionalVault
        self.VaultStoragePath = /storage/fractionalVault

        self.account.save<@FractionalVault.VaultCollection>(<- FractionalVault.createEmptyCollection(), to: FractionalVault.VaultStoragePath)
		self.account.link<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath, target: FractionalVault.VaultStoragePath)
    }
}
 