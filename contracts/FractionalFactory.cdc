
import FractionalVault from "./FractionalVault.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"


pub contract FractionalFactory {

    /// @notice the number of NFT vaults
    pub var vaultCount: UInt256

    /// @notice the mapping of vault number to resource uuid
    pub var vaults: {UInt256: UInt64}

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

    //Mint event
    pub event Mint(token: Address, id: UInt256, price: UInt256, vault: Address, vaultId: UInt256);

    /// @notice the function to mint a new vault
    /// @param _token the ERC721 token address fo the NFT
    /// @param _id the uint256 ID of the token
    /// @return the ID of the vault
    pub fun mint(underlying: Capability<&NonFungibleToken.Collection>): @FractionalVault.Vault {
        //uint256 count = FERC1155(fnft).count() + 1;
        //Initiilize the Vault
        var newVault <- FractionalVault.createVault(id: self.vaultCount, underlying: underlying, settings: self.settings)

        //Mint the Fractions
        /**
            uint256 fractionId = FERC1155(fnft).mint(vault, 10000);
            require(count == fractionId, "mismatch");
        */

        //emit Mint

        //transfer underlying collection

        //transfer fractions to the owner of the underlying

        self.vaults[self.vaultCount] = newVault.uuid
        self.vaultCount =  self.vaultCount + 1
        return <- newVault
    }


    init() {
        self.vaultCount = 0
        self.vaults = {}
        self.settings = Settings()
    }

   

}
