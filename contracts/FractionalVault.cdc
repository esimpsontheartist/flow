/**
  Fractional NFT Vault contract
 */

 import FungibleToken from "./standard/FungibleToken.cdc"
 import FlowToken from "./standard/FLOW.cdc"
 import FUSD from "./standard/FUSD.cdc"
 import NonFungibleToken from "./standard/NonFungibleToken.cdc"
 import EnumerableSet from "./lib/EnumerableSet.cdc"
 import Fraction from "./Fraction.cdc"
 import FractionalFactory from "./FractionalFactory.cdc"


pub contract FractionalVault {

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
    /// @notice An event emitted when someone cashes in Fractions for FUSD from an NFT sale
    pub event Cash(owner: Address, shares: UInt256);

    // @notice An envet emitted when a vault resource is initialized
    pub event Initialized(id: UInt256)

    pub struct ReserveInfo {
        pub var voting: UInt256 //what is voting meant to represent?
        pub var reserve: UFix64

        init(_ voting: UInt256, _ reserve: UFix64){
            self.voting = voting
            self.reserve = reserve
        }
    }

    pub resource Vault {

        pub let id: UInt256

        access(account) let settings: FractionalFactory.Settings

        //The vault that holds fungible tokens for an auction
        priv let bidVault: @FUSD.Vault
        //The collection for the fractions
        priv var fractions: @NonFungibleToken.Collection
        //Collection of the NFTs the user will fractionalize
        priv var underlying: Capability<&NonFungibleToken.Collection> 

        // Auction information// 
        pub var auctionEnd: UFix64?
        pub var auctionLength: UFix64
        pub var reserveTotal: UFix64?
        pub var livePrice: UFix64?
        pub var winning: Address?
        pub var auctionState: State?

        //Vault information//

        //Array of prices with more than 1% voting for them
        access(account) var prices: EnumerableSet.UFix64Set
        //All prices and the number voting for them
        access(account) let priceToCount: {UFix64: UInt256}
        //The price of each user
        access(account) let userPrices: {Address: UFix64} 

        init(
            id: UInt256,
            underlying: Capability<&NonFungibleToken.Collection>,
            settings: FractionalFactory.Settings
        ) {
            self.id = id
            self.settings = settings
            self.fractions <- Fraction.createEmptyCollection()
            self.underlying = underlying
            self.auctionLength = 172800.0 //2 days in seconds 
            self.auctionState = State.inactive
            self.prices = EnumerableSet.UFix64Set()
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
            let toVault = getAccount(to).getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdBalance).borrow() ?? panic("Could not borrow a reference to the account receiver")
            //withdraw 'value' from the bidVault
            let withdrawalVault <- self.bidVault.withdraw(amount: value)
            //deposit the amount
            toVault.deposit(from: <-withdrawalVault)
        }

        // add to a price count
        // add price to reserve calc if 1% are voting for it
        priv fun addToPrice(_ amount: UFix64, _ price: UFix64) {
            self.priceToCount[price] = self.priceToCount[price]! + UInt256(amount)
            //TODO: add IFERC1155(fractions.token).totalSupply(fractions.id)
            if self.priceToCount[price]! > 99 && !self.prices.contains(price) {
               self.prices.add(price)
            }
        }

        // remove a price count
        // remove price from reserve calc if less than 1% are voting for it
        priv fun removeFromPrice(_ amount: UFix64, _ oldPrice: UFix64) {
            self.priceToCount[oldPrice] = self.priceToCount[oldPrice]! - UInt256(amount)
            //if (priceToCount[_price] * 100 >= IFERC1155(fractions.token).totalSupply(fractions.id) && !prices.contains(_price)) {
            if self.priceToCount[oldPrice]! < 100 && !self.prices.contains(oldPrice) {
                self.prices.remove(oldPrice)
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

        /// @notice kick off an auction. Must send reservePrice in FUSD
        pub fun start(_ fusdVault: @FUSD.Vault) {
            pre {
                self.auctionState == State.inactive : "start:no auction starts"
                fusdVault.balance >= self.reservePrice().reserve : "start:too low bid"
                self.reservePrice().voting * 2 >= 0 : "start:not enough voters" //Swap for the equivalent to IFERC1155(fractions.token).totalSupply(fractions.id)
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
            self.sendFUSD(to: self.winning!, value: self.livePrice!);
            
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

            emit Cash(owner: fractions.owner?.address!, shares: 0) //replace 0.0 with 'share'
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

    //function to create a new Vault
    //change to acces(acount), pub now for to avoid getting anoid by the linter
    pub fun createVault(id: UInt256, underlying: Capability<&NonFungibleToken.Collection>, settings: FractionalFactory.Settings): @FractionalVault.Vault {
        return <- create Vault(id: id, underlying: underlying, settings: settings)
    }

    init() {}
}
 