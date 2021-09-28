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

    //pub resource FractionalNFT: @NonFungibleToken.INFT

    //Create a collection resource to hold any NFTs for the user

    //Struct to handle different NFT addresses and corresponding IDs
    pub struct NFT {
        pub var id: UInt64
        pub var address: Address //Could be a resource or something else

        init(id: UInt64, address: Address){
            self.id = id
            self.address = address
        }
    }

    pub resource NFTvault {

        pub let id: UInt256
        /// -----------------------------------
        /// ------ FRACTION INFORMATION -------
        /// -----------------------------------

        //This would refer to the NFTs Address and ID that is being "kept" by the vault
        priv let vaultCollection: @NonFungibleToken.Collection

        //The vault that holds fungible tokens for an auction
        priv let bidVault: @FungibleToken.Vault

        //The collection for the fractional NFTs
        priv let fractionalCollection: @NonFungibleToken.Collection

        //might need something to receive the NFTs

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

        //SUBJETC TO CHANGE
        pub var fractions: NFT 
        //SUBJETC TO CHANGE 
        pub var underlying: NFT 

        //Array of prices with more than 1% voting for them
        access(account) var prices: [UFix64]
        //All prices and the number voting for them
        access(account) let priceToCount: {UFix64: UInt256}
        //The price of each user
        access(account) let userPrices: {Address: UFix64} 

        init(
            id: UInt256,
            fractions: NFT,
            underlying: NFT
        ) {
            self.id = id
            //How to represent 2 days in Cadence?
            self.fractions = fractions
            self.underlying = underlying
            self.auctionLength = 2.0
            self.auctionState = State.inactive
            self.prices = []
            self.userPrices = {}
            self.priceToCount = {}

            //nil variables
            self.auctionEnd = nil
            self.reserveTotal = nil
            self.livePrice = nil
            self.winning = nil

            //creating an empty collection to hold the NFTs
            //Not the right implementation, will need something to store any arbitrary NFT
            //Then maybe multiple ones
            self.vaultCollection <- Fraction.createEmptyCollection()

            self.fractionalCollection <- Fraction.createEmptyCollection()
            
            //bid vault
            self.bidVault <- FUSD.createEmptyVault()

            emit Initialized(id: id)
        }

        /** Need to add this later
            function isLivePrice(uint256 _price) external returns(bool) {
                return prices.contains(_price);
            }
         */


        

        priv fun addToPrice(amount: UInt256, price: UInt256) {
            self.priceToCount[price] = self.priceToCount[price] + amount
            if(self.priceToCount[price] > 99 && !self.prices.contains(price)) {
               prices.add(price)
            }
        }

        priv fun removeFromPrice(amount: UInt256, oldPrice: UInt256) {
            self.priceToCount[oldPrice] = self.priceToCount[oldPrice] - amount
            if(self.priceToCount[oldPrice] < 100 && !self.prices.contains(oldPrice)) {
               var index = 0
               for price in self.prices {
                   if price == oldPrice {
                       prices.remove(index)
                       break
                   }
                   index = index + 1
               }
               
            }
        }

        pub fun updateUserPrice(address: Address, new: UInt256) {
            pub let accountReceiver: PublicAccount = getAccount(address).getCapability<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance)
                .borrow()
                ?? panic("Could not borrow a reference to the account receiver")
            pub var balance: UInt256 = accountReceiver.balance

            addToPrice(balance, new)
            removeFromPrice(balance, userPrices[address])

            userPrices[address] = new
            
            emit PriceUpdate(user: address, price: new)
        }

        /**
            //1. Create a collection for the fractions
            //2. Create a collection that is moved to the curator
            //
            //3. Mint the NFTs to the curator
            //
            //4. Emit "Mint" event
            //
            //5. Add vault to vaults mapping
            //
            //6. Increment vault count
        */

        //Vault functions


        //Resource destruction
        //Add more logic behind conditions before a vault and other resources are destructed
        destroy() {
            log("destroy auction")


            destroy self.vaultCollection
            destroy self.fractionalCollection
            destroy self.bidVault
        }

    }


    //init() -> constructor
    //Only called once when the contract is created, and never again
    init() {
        self.settings = Settings()
    }
}
 