/**
  Fractional NFT Vault contract
 */

 import FungibleToken from "./standard/FungibleToken.cdc"
 import FlowToken from "./standard/FLOW.cdc"
 import FUSD from "./standard/FUSD.cdc"
 import NonFungibleToken from "./standard/NonFungibleToken.cdc"
 import Fraction from "./Fraction.cdc"

//Might want to separete the settings from Vault and moved them to a 'Factory' Contract
pub contract FractionalVault {
    
    ////////////////////////////////////////
    ///////////Factory//////////////////////
    ////////////////////////////////////////
    
    /// @notice the number of NFT vaults
    //pub var vaultCount: UInt256

    /// @notice the mapping of vault number to vault id
    //pub var vaults: {UInt256: UInt256}


    /// @notice the mapping of vault number to vault contract
    //pub let vaults: {UInt256: Address} (Might change Address for some other type/resource)

    //pub event Mint(token: Address, id: UInt256, price: UInt256, vault: Address, vaultId: UInt256);

    //Vault settings Events
    pub event UpdateMaxAuctionLength(old: UFix64, new: UFix64)
    pub event UpdateMinAuctionLength(old: UFix64, new: UFix64)
    pub event UpdateGovernanceFee(old: UFix64, new: UFix64)
    pub event UpdateMinBidIncrease(old: UFix64, new: UFix64)
    pub event UpdateMinVotePercentage(old: UFix64, new: UFix64)
    pub event UpdateMaxReserveFactor(old: UFix64, new: UFix64)
    pub event UpdateMinReserveFactor(old: UFix64, new: UFix64)
    pub event UpdateFeeReceiver(old: Address, new: Address)
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

    access(account) let settings: Settings

    ////////////////////////////////////////
    /////////////Vault//////////////////////
    ////////////////////////////////////////

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
    /// @notice An event emitted when someone cashes in ERC20 tokens for ETH from an ERC721 token sale
    pub event Cash(owner: Address, shares: UFix64);

    // @notice An envet emitted when a vault resource is initialized
    pub event Initialized(id: UInt256)

    pub struct ReserveInfo {
        pub var voting: UFix64
        pub var reserve: UFix64

        init(_ voting: UFix64, _ reserve: UFix64){
            self.voting = voting
            self.reserve = reserve
        }
    }

    pub resource NFTvault {

        pub let id: UInt256

        //The vault that holds fungible tokens for an auction
        priv let bidVault: @FungibleToken.Vault
        //The collection for the fractions
        priv var fractions: @Fraction.Collection
        //Collection of the NFTs the user will fractionalize
        priv var underlying: Capability<&NonFungibleToken.Collection> 

        /// -----------------------------------
        /// ------ Auction information --------
        /// -----------------------------------
        pub var auctionEnd: UFix64?
        pub var auctionLength: UFix64
        pub var reserveTotal: UFix64?
        pub var livePrice: UFix64?
        pub var winning: Address?
        pub var auctionState: State?

        /// -----------------------------------
        /// ------ Vault information ----------
        /// -----------------------------------

        //Array of prices with more than 1% voting for them
        access(account) var prices: [UFix64]
        //All prices and the number voting for them
        access(account) let priceToCount: {UFix64: UFix64}
        //The price of each user
        access(account) let userPrices: {Address: UFix64} 

        init(
            id: UInt256,
            fractions: NFT,
            underlying: Capability<&NonFungibleToken.Collection>
        ) {
            self.id = id
            self.fractions <- Fraction.createEmptyCollection()
            self.underlying = underlying
            //How to represent 2 days in Cadence?
            self.auctionLength = 2.0
            self.auctionState = State.inactive
            self.prices = []
            self.userPrices = {}
            self.priceToCount = {}

            //optional nil variables
            self.auctionEnd = nil
            self.reserveTotal = nil
            self.livePrice = nil
            self.winning = nil
            
            //bid vault
            self.bidVault <- FUSD.createEmptyVault()

            emit Initialized(id: id)
        }

        
        pub fun isLivePrice(price: UFix64): Bool {
            return self.prices.contains(price);
        }

        priv fun sendFUSD(to: Address, value: UFix64) {
            //borrow a capability for the vault of the 'to' address
            let toVault = getAccount(to).getCapability<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance).borrow() ?? panic("Could not borrow a reference to the account receiver")
            //withdraw 'value' from the bidVault
            let withdrawalVault = self.bidVault.withdraw(amount: value)
            //deposit the amount
            toVault.deposit(amount: <-withdrawalVault)
        }

        // add to a price count
        // add price to reserve calc if 1% are voting for it
        priv fun addToPrice(_ amount: UFix64, _ price: UFix64) {
            self.priceToCount[price] = self.priceToCount[price]! + amount
            if self.priceToCount[price]! > 99.0 && !self.prices.contains(price) {
               self.prices.append(price)
            }
        }

        // remove a price count
        // remove price from reserve calc if less than 1% are voting for it
        priv fun removeFromPrice(_ amount: UFix64, _ oldPrice: UFix64) {
            self.priceToCount[oldPrice] = self.priceToCount[oldPrice]! - amount
            if self.priceToCount[oldPrice]! < 100.0 && !self.prices.contains(oldPrice) {
               var index = 0
               for price in self.prices {
                   if price == oldPrice {
                       self.prices.remove(at: index)
                       break
                   }
                   index = index + 1
               }
               
            }
        }

        pub fun updateUserPrice(address: Address, new: UFix64) {
            let accountReceiver = getAccount(address).getCapability<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance).borrow() ?? panic("Could not borrow a reference to the account receiver")
            var balance: UFix64 = accountReceiver.balance
            self.addToPrice(balance, new)
            self.removeFromPrice(balance, self.userPrices[address]!)

            self.userPrices[address] = new
            
            emit PriceUpdate(user: address, price: new)
        }

        /** THIS PROBABLY BELONGS IN THE FRACTION NFT CONTRACT
            function onTransfer(address _from, address _to, uint256 _amount) external {
                require(msg.sender == fractions.token, "not allowed");
                
                // we are burning
                if (_to == address(0)) {
                    _removeFromPrice(_amount, userPrices[_from]);
                }
                else if (_from == address(0)) {
                    _addToPrice(_amount, userPrices[_to]);
                } else {
                    _removeFromPrice(_amount, userPrices[_from]);
                    _addToPrice(_amount, userPrices[_to]);
                }
            }
        */

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

            var tempPrices = self.prices
            tempPrices = self.sort(tempPrices)
            var voting = 0.0
            var x = 0
            while x < tempPrices.length {   
                if tempPrices[x] != 0.0 {
                    voting = voting + self.priceToCount[tempPrices[x]]!
                }
                x = x + 1
            }

            var reserve = 0.0 
            var count = 0.0
            var y = 0
            while y < tempPrices.length {
                if tempPrices[y] != 0.0 {
                    count = count + self.priceToCount[tempPrices[y]]!
                }
                if count * 2.0 >= voting {
                    reserve = tempPrices[y]
                    break
                }
            }
            return ReserveInfo(voting, reserve)
        }

        /// @notice kick off an auction. Must send reservePrice in FUSD
        pub fun start(_ fusdVault: @FUSD.Vault) {
            pre {
                self.auctionState == State.inactive : "start:no auction starts"
                fusdVault.balance >= self.reservePrice().reserve : "start:too low bid"
                self.reservePrice().voting * 2.0 >= 0.0 : "start:not enough voters" //Swap for the equivalent to IFERC1155(fractions.token).totalSupply(fractions.id)
            }

            self.auctionEnd = getCurrentBlock().timestamp + self.auctionLength
            self.auctionState = State.live

            self.livePrice = fusdVault.balance
            self.winning = fusdVault.owner?.address

            emit Start(buyer: fusdVault.owner?.address!, price: fusdVault.balance)

            //Deposit the bid into the vault
            self.bidVault.deposit(from: <-fusdVault)
        }

        pub fun bid(_ fusdVault: @FUSD.Vault) {
            pre {
                self.auctionState == State.inactive : "bid:no auction starts"
                fusdVault.balance * 100.0 >= self.livePrice! * 105.0 : "bid:too low bid"
                getCurrentBlock().timestamp < self.auctionEnd! : "bid:auction end"
            }

            //Need to represent 15 minutes
            if self.auctionEnd! - getCurrentBlock().timestamp <= 15.0 {
                self.auctionEnd = self.auctionEnd! + 15.0
            }
            
            //refund the last bidder
            self.sendFUSD(to: self.winning, amount: self.livePrice);
            
            self.livePrice = fusdVault.balance
            self.winning = fusdVault.owner?.address

            emit Bid(buyer: fusdVault.owner?.address!, price: fusdVault.balance)

            destroy fusdVault
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

            emit Cash(owner: fractions.owner?.address!, shares: 0.0) //replace 0.0 with 'share'
            destroy fractions
        }
        
        //Resource destruction
        //Add more logic behind conditions before a vault and other resources are destructed
        destroy() {
            log("destroy auction")

            destroy self.bidVault
            destroy  self.fractions
        }

    }

    init() {
        self.settings = Settings()
    }
}
 