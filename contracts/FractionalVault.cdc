import FungibleToken from "./standard/FungibleToken.cdc"
import FlowToken from "./standard/FLOW.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"
import EnumerableSet from "./lib/EnumerableSet.cdc"
import NFTCollection from "./lib/NFTCollection.cdc"
import Fraction from "./Fraction.cdc"

 /**
  Fractional NFT Vault contract
 */

pub contract FractionalVault {

    /// -----------------------------------
    /// ----------- Factory ---------------
    /// -----------------------------------

    /// @notice the number of NFT vaults
    pub var vaultCount: UInt256

    /// @notice the mapping of vault number to esource uuid
    pub var vaults: {UInt256: UInt64}

    pub let VaultStoragePath: StoragePath
	pub let VaultPublicPath: PublicPath

     //Vault settings
    pub struct Settings {
        pub var maxAuctionLength: UFix64
        pub var minAuctionLength: UFix64
        pub var governanceFee: UFix64
        pub let maxGovFee: UFix64 //10% is the max
        pub var minBidIncrease: UFix64
        pub let maxMinBidIncrease: UFix64 //10% bid increase is the max
        pub let minMinBidIncrease: UFix64 //1% is the bid increase min
        pub var minVotePercentage: UFix64 //Percentage of tokens required to be voting for an auction to start
        pub var maxReserveFactor: UFix64 // the max % increase over the initial
        pub var minReserveFactor: UFix64 // the max % decreaseFactor from the initial
        pub var feeReceiver: Address // the address that receives auction fees

            //need to set the right initial values
            init() {
            self.maxAuctionLength =  0.0
            self.minAuctionLength = 0.0
            self.governanceFee = 0.0
            self.maxGovFee = 0.0
            self.minBidIncrease = 0.0
            self.maxMinBidIncrease = 0.0
            self.minMinBidIncrease = 0.0
            self.minVotePercentage = 0.0
            self.maxReserveFactor = 0.0
            self.minReserveFactor = 0.0
            self.feeReceiver = 0x0
        }

        //access(account) -> only the account and contracts inside of it read this function
        access(account) fun setMaxAuctionLength(length: UFix64) {
            //require -> pre (or 'precondition') in Cadence
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

        access(account) fun setGovernanceFee(fee: UFix64) {
            pre { 
                fee <= self.maxGovFee: "fee too high"
            }

            emit UpdateGovernanceFee(old: self.governanceFee, new: fee)
            self.governanceFee = fee
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
            emit UpdateFeeReceiver(old: self.feeReceiver, new: receiver)
            self.feeReceiver = receiver
        }

    }

    /// @notice a settings constant controlled by governance
    access(account) let settings: Settings

    //Vault settings Events
    pub event UpdateMaxAuctionLength(old: UFix64, new: UFix64)
    pub event UpdateMinAuctionLength(old: UFix64, new: UFix64)
    pub event UpdateGovernanceFee(old: UFix64, new: UFix64)
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
    pub event PriceUpdate(user: Address, price: UFix64);
    /// @notice An event emitted when an auction starts
    pub event Start(buyer: Address, price: UFix64);
    /// @notice An event emitted when a bid is made
    pub event Bid(buyer: Address, price: UFix64);
    /// @notice An event emitted when an auction is won
    pub event Won(buyer: Address, price: UFix64);
    /// @notice An event emitted when someone redeems all tokens for the NFT
    pub event Redeem(redeemer: Address);
    /// @notice An event emitted when someone cashes in Fractions for FLOW from an NFT sale
    pub event Cash(owner: Address, shares: UInt256);
    //Mint event
    pub event Mint(underlyingOwner: Address, vaultId: UInt256);


    // @notice An envet emitted when a vault resource is initialized
    pub event Initialized(id: UInt256)

    pub struct ReserveInfo {
        pub var voting: UInt256
        pub var reserve: UFix64

        init(_ voting: UInt256, _ reserve: UFix64){
            self.voting = voting
            self.reserve = reserve
        }
    }

    pub resource Vault {

        pub let id: UInt256

        //expose all these things through functions
        access(account) let settings: Settings

        //The vault that holds fungible tokens for an auction
        access(account) let bidVault: @FungibleToken.Vault
        //The collection for the fractions
        access(account) var fractions: @NonFungibleToken.Collection
        //Collection of the NFTs the user will fractionalize (UInt64 is meant to be the NFT's uuid)
        //change access control later
        access(account) var underlying: @NFTCollection.Collection

        // Auction information// 
        access(contract) var auctionEnd: UFix64?
        access(contract) var auctionLength: UFix64
        access(contract) var reserveTotal: UFix64?
        access(contract) var livePrice: UFix64?
        access(contract) var winning: Address?
        access(contract) var auctionState: State?

        //Vault information//
        //change to access(account)
        //Array of prices with more than 1% voting for them
        pub let prices: EnumerableSet.UFix64Set
        //All prices and the number voting for them
        pub let priceToCount: {UFix64: UInt256}
        //The price of each user
        pub let userPrices: {Address: UFix64} 

        init(
            id: UInt256,
            settings: Settings
        ) {
            self.id = id
            self.settings = FractionalVault.settings
            self.auctionLength = 172800.0 //2 days in seconds 
            self.auctionState = State.inactive
            self.prices = EnumerableSet.UFix64Set()
            self.userPrices = {}
            self.priceToCount = {}
            

            // Resources
            self.bidVault <- FlowToken.createEmptyVault()
            self.fractions <- Fraction.createEmptyCollection()
            self.underlying <- NFTCollection.createEmptyCollection()

            //optional nil variables
            self.auctionEnd = nil
            self.reserveTotal = nil
            self.livePrice = nil
            self.winning = nil
            
            
            
            emit Initialized(id: id)
        }

        
        pub fun isLivePrice(price: UFix64): Bool {
            return self.prices.contains(price);
        }

        priv fun sendFlow(to: Address, value: UFix64) {
            //borrow a capability for the vault of the 'to' address
            let toVault = getAccount(to).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenBalance).borrow() ?? panic("Could not borrow a reference to the account receiver")
            //withdraw 'value' from the bidVault
            let withdrawalVault <- self.bidVault.withdraw(amount: value)
            //deposit the amount
            toVault.deposit(from: <-withdrawalVault)
        }
        
        // add to a price count
        // add price to reserve calc if 1% are voting for it
        //change to access(account), pub now to avoid linter errrors
        pub fun addToPrice(_ amount: UInt256, _ price: UFix64) {
            self.priceToCount[price] = self.priceToCount[price]! + amount
            //TODO: add IFERC1155(fractions.token).totalSupply(fractions.id)
            if self.priceToCount[price]! > 99 && !self.prices.contains(price) {
               self.prices.add(price)
            }
        }

        // remove a price count
        // remove price from reserve calc if less than 1% are voting for it
        //change to access(account), pub now to avoid linter errrors
        pub fun removeFromPrice(_ amount: UInt256, _ oldPrice: UFix64) {
            self.priceToCount[oldPrice] = self.priceToCount[oldPrice]! - amount
            //if (priceToCount[_price] * 100 >= IFERC1155(fractions.token).totalSupply(fractions.id) && !prices.contains(_price)) {
            if self.priceToCount[oldPrice]! < 100 && !self.prices.contains(oldPrice) {
                self.prices.remove(oldPrice)
            }
        }

        pub fun updateUserPrice(address: Address, new: UFix64) {
            //Get fraction balance
            let accountReceiver = getAccount(address).getCapability(Fraction.CollectionPublicPath).borrow<&{Fraction.CollectionPublic}>() ?? panic("Could not borrow a reference to the account receiver")
            //Amount of fractions the user holds
            var amount = UInt256(accountReceiver.getIDs().length)
            self.addToPrice(amount, new)
            self.removeFromPrice(amount, self.userPrices[address]!)

            self.userPrices[address] = new
            
            emit PriceUpdate(user: address, price: new)
        }

        priv fun slice(_ array: [UFix64], _ begin: Integer, _ last: Integer): [UFix64] {
            var arr: [UFix64] = []
            var i = begin
            while i < last {
                arr.append(array[i])
                i = i + 1
            }
            return arr
        }

        priv fun sort(_ array: [UFix64]): [UFix64] {
            //create copy because arguments are constant
            var arr = array
            var length = arr.length
            //base case
            if length < 2 {
                return arr
            }

            //position of the partition
            var currentPosition = 0

            var i = 1
            while i < length {
                if arr[i] <= arr[0] {
                    currentPosition = currentPosition + 1
                    arr[i] <-> arr[currentPosition]
                }
            }

            //swap
            arr[0] <-> arr[currentPosition]

            var left: [UFix64] = self.sort(self.slice(arr, 0, currentPosition))
            var right: [UFix64] = self.sort(self.slice(arr, currentPosition + 1, length))

            //mergin the arrays
            arr = left
            arr.append(arr[currentPosition])
            arr.appendAll(right)
            return arr
        }
        
        pub fun reservePrice(): ReserveInfo {

            var tempPrices = self.prices.values()
            tempPrices = self.sort(tempPrices)
            var voting: UInt256 = 0
            var x: Int = 0
            while x < tempPrices.length {   
                if tempPrices[x] != 0.0 {
                    voting = voting + self.priceToCount[tempPrices[x]]!
                }
                x = x + 1
            }

            var reserve = 0.0 
            var count: UInt256 = 0
            var y = 0
            while y < tempPrices.length {
                if tempPrices[y] != 0.0 {
                    count = count + self.priceToCount[tempPrices[y]]!
                }
                if count * 2 >= voting {
                    reserve = tempPrices[y]
                    break
                }
            }
            return ReserveInfo(voting, reserve)
        }

        /// @notice kick off an auction. Must send reservePrice in FLOW
        pub fun start(_ flowVault: @FlowToken.Vault) {
            pre {
                self.auctionState == State.inactive : "start:no auction starts"
                flowVault.balance >= self.reservePrice().reserve : "start:too low bid"
                self.reservePrice().voting * 2 >= 0 : "start:not enough voters" //Swap for the equivalent to IFERC1155(fractions.token).totalSupply(fractions.id)
            }

            self.auctionEnd = getCurrentBlock().timestamp + self.auctionLength
            self.auctionState = State.live

            self.livePrice = flowVault.balance
            self.winning = flowVault.owner?.address

            emit Start(buyer: flowVault.owner?.address!, price: flowVault.balance)

            //Deposit the bid into the vault
            self.bidVault.deposit(from: <-flowVault)
        }

        pub fun bid(_ flowVault: @FlowToken.Vault) {
            pre {
                self.auctionState == State.inactive : "bid:no auction starts"
                flowVault.balance * 100.0 >= self.livePrice! * 105.0 : "bid:too low bid"
                getCurrentBlock().timestamp < self.auctionEnd! : "bid:auction end"
            }

            //Need to represent 15 minutes
            if self.auctionEnd! - getCurrentBlock().timestamp <= 15.0 {
                self.auctionEnd = self.auctionEnd! + 15.0
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

            // transfer NFT to winner
            //IERC721(underlying.token).transferFrom(address(this), winning, underlying.id);

            self.auctionState = State.ended

            emit Won(buyer: self.winning!, price: self.livePrice!)
        }

        //Replace with the custom Fractional NFT code
        pub fun redeem(_ fractions: @FungibleToken.Vault) {
            pre {
                self.auctionState == State.inactive : "redeem:no redeeming"
            }

            //take tokens

            //transfer NFT to the owner of the fractions

            self.auctionState = State.redeemed

            emit Redeem(redeemer: fractions.owner?.address!)

            destroy fractions
        }

        pub fun cash(_ fractions: @FungibleToken.Vault) {
            pre {
                self.auctionState == State.ended : "cash:vault not closed yet"
                fractions.balance > 0.0 : "cash:no tokens to cash out"
            }

            //var share = (fractions.balance * contractBalance) / totalSupplyOfFraction

            //take fractions

            //sendFUSD

            emit Cash(owner: fractions.owner?.address!, shares: 0) //replace 0.0 with 'share'
            destroy fractions
        }
        
        //Resource destruction
        //Add more logic behind conditions before a vault and other resources are destructed
        destroy() {
            log("destroy auction")
            destroy self.underlying
            destroy self.bidVault
            destroy  self.fractions
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

        // lockVault takes a Vault and adds it to the vaults dictionary
        //change to access(account), pub now to avoid linter errrors
        pub fun depositVault(vault: @FractionalVault.Vault) {
            let vault <- vault 

            let id: UInt256 = vault.id

            let oldVault <- self.vaults[id] <- vault

            //add event for locking a vault?

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

    //function for anyone to call to create the collection where they can keep their
    pub fun createEmptyCollection(): @FractionalVault.VaultCollection {
        return <- create VaultCollection()
    }

    /// @notice the function to mint a new vault
    /// @param collection the collection for the underlying set of NFTS
    /// @return the ID of the vault
    /// Might want to consider changing the access control
    pub fun mint(collection: @NFTCollection.Collection): @FractionalVault.Vault {

        var count = Fraction.count + 1
        //Initialize a vault
        let vault <- create Vault(id: Fraction.count, settings: self.settings)

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

        self.vaults[self.vaultCount] = vault.uuid
        self.vaultCount =  self.vaultCount + 1
       
        var vaultCollection = self.account.getCapability(FractionalVault.VaultPublicPath).borrow<&{FractionalVault.VaultCollectionPublic}>() ?? panic("Could not borrow a reference to the account receiver")
        
        //destroy the collection sent
        destroy collection
        //destroy the fraction resources since they have been moved
        destroy fractions
        //return the vault
        return <- vault
    }

    init() {
        self.vaultCount = 0
        self.vaults = {}
        self.settings = Settings()
        self.VaultPublicPath = /public/fractionalVault
        self.VaultStoragePath = /storage/fractionalVault

        self.account.save<@FractionalVault.VaultCollection>(<- FractionalVault.createEmptyCollection(), to: FractionalVault.VaultStoragePath)
		self.account.link<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath, target: FractionalVault.VaultStoragePath)
    }
}
 