import FungibleToken from "./FungibleToken.cdc"
import Modules from "./Modules.cdc"
import Fraction from "./Fraction.cdc"

// A fixed price sale for Fractions that utilizes lazy minting
pub contract FixedPriceSale {

    pub event ContractInitialized()

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    //Number of listings that have occured (also used to generate a Sale ID)
    pub var numOfListings: UInt64
    //Mapping of IDs to listings
    priv let listings: {UInt64: ListingData}

    pub event Purchase(listingData: ListingData)

    pub event Listing(listingData: ListingData)

    pub event Cancelled(listingData: ListingData)

    pub struct ListingData {
        pub let id: UInt64
        pub let vaultId: UInt64
        pub let fractionData: Fraction.FractionData
        pub let salePrice: UFix64
        pub let amount: UInt256
        pub let salePaymentType: Type
        pub let receiver: Address

        init(
            _ id: UInt64,
            _ vaultId: UInt64, 
            _ fractionData: Fraction.FractionData,
            _ amount: UInt256, 
            _ salePrice: UFix64,
            _ salePaymentType: Type,
            _ receiver: Address
        ) {
            self.id = id
            self.vaultId = vaultId
            self.fractionData = fractionData
            self.amount = amount
            self.salePrice = salePrice
            self.salePaymentType = salePaymentType
            self.receiver = receiver
        }
    }

    pub resource interface SalePublic { 
        pub let id: UInt64
        pub let vaultId: UInt64
        pub let salePrice: UFix64
        pub let amount: UInt256
        pub let salePaymentType: Type
        pub let receiver: Capability<&{FungibleToken.Receiver}>
    }

    pub resource Sale: SalePublic {
        
        pub let id: UInt64
        pub let minter: Capability<&{Modules.CappedMinterCollection}>
        pub let vaultId: UInt64
        pub let salePrice: UFix64
        pub let amount: UInt256
        pub let salePaymentType: Type
        pub let receiver: Capability<&{FungibleToken.Receiver}>
        
        init(
            id: UInt64,
            minter: Capability<&{Modules.CappedMinterCollection}>,
            vaultId: UInt64,
            amount: UInt256,
            salePrice: UFix64,
            salePaymentType: Type,
            receiver: Capability<&{FungibleToken.Receiver}>
        ){
            pre {
                minter.check() == true : "minter capability must be linked"
                receiver.check() == true : "receiver capability must be linked"
                amount <= 100 : "can't list more than 100 fractions per listing"
            }

            self.id = id
            self.minter = minter
            self.vaultId = vaultId
            self.salePrice = salePrice
            self.amount = amount
            self.salePaymentType = salePaymentType
            self.receiver = receiver

            let listingData = ListingData(
                self.id,
                self.vaultId,
                Fraction.vaultToFractionData[self.vaultId]!,
                self.amount,
                self.salePrice,
                self.salePaymentType,
                self.receiver.address
            )
        
            emit Listing(listingData: listingData)

            FixedPriceSale.listings[self.id] = listingData
        }

        pub fun buyFractions(payment: @FungibleToken.Vault): @Fraction.Collection {
            pre {
                payment.isInstance(self.salePaymentType) : "buyFractions:payment made with the wrong tokens"
                payment.balance == UFix64(self.amount) * self.salePrice : "buyFractions:payment is not enough"
            }

            let receiver = self.receiver.borrow() ?? panic("purchase:could not borrow a reference for the receiver")

            receiver.deposit(from: <- payment)

            let minter = self.minter.borrow() ?? panic("purchase:could not borrow a minter capability for the purchase")

            let minterRef = minter.borrowMinter(id: self.vaultId)!
            return <- minterRef.mint(amount: self.amount)
        }

        destroy() {
             FixedPriceSale.listings[self.id] = nil
        }

    }

    pub resource interface FixedSaleCollectionPublic {
        pub fun purchaseListing(listingId: UInt64, buyTokens: @FungibleToken.Vault): @Fraction.Collection
        pub fun getIDs(): [UInt64]
        pub fun borrowListing(id: UInt64): &{SalePublic}?
    }

    pub resource FixedSaleCollection:  FixedSaleCollectionPublic {

        pub var forSale: @{UInt64: Sale}

        //Curator list a number of fractions for sale
        pub fun list(
            vaultId: UInt64,
            minter: Capability<&{Modules.CappedMinterCollection}>,
            amount: UInt256, 
            salePrice: UFix64,
            salePaymentType: Type,
            receiver: Capability<&{FungibleToken.Receiver}>
        ) {
            pre {
                minter.check() == true : "list:curator capability must be linked"
                receiver.check() == true : "list:receiver capability must be linked"
                
            }

            let minterCollection = minter.borrow() ?? panic("list:could not borrow a minter capability for the listing")
            let ids = minterCollection.getIDs()
            assert(ids.contains(vaultId), message: "list:no minter for the given vaultId")
            let minterRef = minterCollection.borrowMinter(id: vaultId)!
            assert(Fraction.fractionSupply[vaultId]! + amount <= minterRef.maxSupply, message: "list:amount will exceed max supply")

            let listing <- create Sale(
                id: FixedPriceSale.numOfListings, 
                minter: minter,
                vaultId: vaultId,
                amount: amount,
                salePrice: salePrice,
                salePaymentType: salePaymentType,
                receiver: receiver
            )

            let nilList <- self.forSale[FixedPriceSale.numOfListings] <- listing
            destroy nilList

            FixedPriceSale.numOfListings = FixedPriceSale.numOfListings + 1
        }

        //purchase
        pub fun purchaseListing(listingId: UInt64, buyTokens: @FungibleToken.Vault): @Fraction.Collection {

            let listing <- self.forSale.remove(key: listingId) ?? panic("purchaseListing:missing listing")

            let fractions <- listing.buyFractions(payment: <- buyTokens)
            //Add event for purchase
            let listingData = FixedPriceSale.listings[listingId]!
            emit Purchase(listingData: listingData)
            destroy listing
            
            return <- fractions
        }

        //cancel
        pub fun cancelListing(listingId: UInt64) {
            let listing <- self.forSale.remove(key: listingId) ?? panic("cancelListing:missing listing")
            let listingData = FixedPriceSale.listings[listingId]!
            emit Cancelled(listingData: listingData)
            destroy listing
        }

        pub fun getIDs(): [UInt64] {
            return self.forSale.keys
        }

        pub fun borrowListing(id: UInt64): &{SalePublic}? {
            if self.forSale[id] != nil {
				return &self.forSale[id] as &{SalePublic}
			} else {
				return nil
			}
        }

        init(){
            self.forSale <- {}
        }

        destroy() {
            destroy self.forSale
        }
    }

    pub fun createFixedPriceSaleCollection(): @FixedSaleCollection {
        return <- create FixedSaleCollection()
    }

    pub fun getListing(id: UInt64): ListingData? {
        return self.listings[id]
    }

    pub init() {
        self.numOfListings = 0
        self.listings = {}

        self.CollectionPublicPath= /public/FixedPriceSale
        self.CollectionStoragePath= /storage/FixedPriceSale

        emit ContractInitialized()
    }

}