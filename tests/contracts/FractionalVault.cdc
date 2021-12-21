import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import Fraction from "./Fraction.cdc"
import CoreVault from "./CoreVault.cdc"
import PriceBook from "./PriceBook.cdc"
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
    pub let vaultAddress: Address

    pub let VaultStoragePath: StoragePath
	pub let VaultPublicPath: PublicPath
    pub let AdministratorStoragePath: StoragePath

    pub event ContractInitialized()

    pub var feeReceiver: Capability<&{FungibleToken.Receiver}>?

    pub resource Administrator {
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
    pub event Cash(owner: Address, amount: UFix64);
    // @notice An envet emitted when a FractionalVault.Vault gets initiated
    pub event VaultInitiated(
        curator: Address,
        bidVaultType: Type,
        underlyingType: Type,
        maxSupply: UInt256,
    );


    pub fun updateFractionPrice(_ vaultId: UInt256, collection: &Fraction.BulkCollection, startId: UInt64, amount: UInt256, new: UFix64) {
        
        let fractionsOwner = collection.owner?.address!

        let fractionIds = collection.getIDsByVault(vaultId: vaultId)

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
            let fraction = collection.borrowFraction(id: id)!
            assert(fraction.vaultId == vaultId, message: "updateFractionPrice:mismatched vaultIDs")
            let id = fraction.id
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

        access(contract) let vault: @CoreVault.Vault
        //The vault that holds fungible tokens for an auction
        access(contract) let bidVault: @FungibleToken.Vault
        //The type of Fungible Token that the vault accepts
        pub let bidVaultType: Type
        //A way for the vault to hold fractions that are deposited for redemption or cashing in
        priv var fractions: @[Fraction.Collection]
        //Max supply the user allows to exist
        access(contract) var maxSupply: UInt256

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

            post {
                maxSupply >= 1000 : "init:max supply cannot be less than the minimum allowed supply"
            }
            
            self.vault <- vault
            self.bidVault <- bidVault
            self.bidVaultType = bidVaultType
            self.auctionLength = 172800.0 //2 days in seconds 
            self.auctionState = State.inactive
            self.maxSupply = maxSupply
            // Resources
            self.fractions <- []
            
            //optional nil variables
            self.auctionEnd = nil
            self.livePrice = nil
            self.winning = nil
            self.refundCapability = nil
            
            emit VaultInitiated(
                curator: self.vault.curator.address,
                bidVaultType: bidVaultType,
                underlyingType: self.vault.underlyingType,
                maxSupply: maxSupply
            )
        }

        pub fun isLivePrice(price: UFix64): Bool {
            return PriceBook.prices[self.vault.uuid]!.contains(price);
        }

        // function to borrow a reference to the underlying collection
        // can be used to deposit to the vault
        pub fun borrowUnderlying(): &{NonFungibleToken.CollectionPublic} {
            return self.vault.borrowPublicCollection()
        }

        // function to get an auth reference to a given NFT, which can be upcasted to the original Type
        access(account) fun borrowUnderlyingRef(id: UInt64): auth &NonFungibleToken.NFT {
            return self.vault.pull(id: id)
        }

        pub fun vaultBalance(): &{FungibleToken.Balance} {
            return &self.bidVault as &{FungibleToken.Balance}
        }

        pub fun getFractionIDsAt(index: Int) : [UInt64] {
            return self.fractions[index].getIDs()
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
                PriceBook.reservePrice(self.vault.uuid).voting * 2 >= self.maxSupply : "start:not enough voters"
                bidder.check() == true : "start:collection capability must be linked"
                refund.check() == true : "start:refund capability must be linked"
                ftVault.isInstance(self.bidVaultType) : "start:bid is not the requested fungible token"
                ftVault.balance >= PriceBook.reservePrice(self.vault.uuid).reserve : "start:too low bid"
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
                UInt256(collection.getIDsByVault(vaultId: self.vault.id).length) == Fraction.maxVaultSupply[self.vault.id] : "redeem:collection does not contain all fractions"
            }

            let bidderRef = redeemer.borrow() ?? panic("redeem:could not borrow a reference for the bidders capability")
            assert(bidderRef.isInstance(self.vault.underlyingType), message: "redeem:bidder's collection capability does not match the vault")
            
            //Push the fraction collection to the array
            self.fractions.append(<- collection.withdrawCollection(vaultId: self.vault.id))

            let redeemersCollection = redeemer.borrow() ?? panic("redeem:could not borrow a reference to the redeemer's collection capability")

            //transfer NFTs to the owner of the fractions
            let collection <- self.vault.end()
            let keys = collection.getIDs()
            for key in keys {
                redeemersCollection.deposit(token: <- collection.withdraw(withdrawID: key))
            }
            destroy collection

            self.auctionState = State.redeemed

            emit Redeem(redeemer: redeemer.address, ids: keys)
            
        }

        pub fun cash(collection: &Fraction.BulkCollection, collector: Capability<&{FungibleToken.Receiver}>) {
            pre {
                self.auctionState == State.ended : "cash:vault not closed yet"
                collection.getIDsByVault(vaultId: self.vault.id).length != 0 : "cash:collection does not contain fractions for this vault"
                collector.check() == true : "cash:collector capability is not linked"
            }
            
            let collectorRef = collector.borrow() 
            ?? panic("cash:could not borrow a reference from the collector's fungible token capability")
            assert(collectorRef.isInstance(self.bidVaultType), message: "cash:collector's capability is not the requested token")

            let fractions <- collection.withdrawCollection(vaultId: self.vault.id)

            //calculate share of the total fraction supply for the vault (Need to check the math)
            var share = (UFix64(fractions.getIDs().length) * self.bidVault.balance) / UFix64(Fraction.fractionSupply[self.vault.id]!)

            //Transfer fractions to the vault
            self.fractions.append(<- fractions)

            //sendFlow
            self.sendFungibleToken(to: collector, value: share)

            emit Cash(owner: collector.address, amount: share)
        }

        //Resource destruction
        //Add more logic behind conditions before a vault and other resources are destructed
        destroy() {
            pre {
                self.auctionState == FractionalVault.State.redeemed || self.auctionState == FractionalVault.State.ended : "destroy:invalid status for destroying vault"
                self.bidVault.balance == 0.0 : "destroy:bidVault balance is not empty"
                self.fractions.length == 0 : "destroy:fractions have not been fully cashed or redeemed"
            }
            destroy self.vault
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
        vault: @CoreVault.Vault,
        bidVault: @FungibleToken.Vault,
        bidVaultType: Type,
        maxSupply: UInt256,
        name: String?,
        description: String?,
    ) {

        //Initialize a vault
        let vault <- create Vault(
            vault: <- vault,
            bidVault: <- bidVault, 
            bidVaultType: bidVaultType,
            maxSupply: maxSupply
        )

        Fraction.maxVaultSupply[vault.id] = maxSupply

        Fraction.vaultToFractionData[vault.id] = Fraction.FractionData(
            vaultId: vault.id,
            uri: Fraction.uriEndpoint.concat(vault.id.toString()),
            curator: vault.curator.address,
            name: name ?? "Fractional Vault #".concat(vault.id.toString()),
            description: description ?? "One or more NFTs fractionalized at fractional.art"
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
        curator: Capability<&Fraction.BulkCollection>,
    ){

        pre {
            curator.check() == true : "mintVaultFractions:curator capability must be linked"
        }
        
        //Get capability for the vault
        let vaultCollection = getAccount(self.vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() 
        ?? panic("Could not borrow a reference to the Fractional Vault Collection")

        let vault = vaultCollection.borrowVault(id: vaultId) ?? panic("Could not borrow a reference for the given VaultId")

        assert(vault.curator.address == curator.address, message: "this address is not permitted to mint fractions for this vault")
        
        //mint the fractions
        let fractions <- Fraction.mintFractions(
            amount: 100, 
            vaultId: self.vaultCount - 1
        )

        //capability to deposit fractions to the owner of the underlying NFT
        let curator =  getAccount(vault.curator.address)
        let fractionCapability = curator.getCapability(Fraction.CollectionPublicPath).borrow<&{Fraction.BulkCollectionPublic}>() 
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
 