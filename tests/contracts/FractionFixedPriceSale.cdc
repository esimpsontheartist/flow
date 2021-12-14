import FungibleToken from "./FungibleToken.cdc"
import Fraction from "./Fraction.cdc"
import FractionalVault from "./FractionalVault.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"

// A fixed price sale for Fractions that utilizes lazy minting
pub contract FractionFixedPriceSale {

    pub event ContractInitialized()

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    //Number of listings that have occured (also used to generate a Sale ID)
    pub var numOfListings: UInt64
    //Mapping of IDs to listings
    pub var listings: {UInt64: ListingData}

    pub event Purchase(listingData: ListingData)

    pub event Listing(listingData: ListingData)

    pub event Cancelled(listingData: ListingData)

    pub struct ListingData {
        pub let saleId: UInt64
        pub let vaultId: UInt256
        pub let fractionData: Fraction.FractionData
        pub let curator: Address
        pub let amount: UInt256
        pub let salePrice: UFix64
        pub let salePaymentType: Type
        pub let receiver: Address

        init(
            _ saleId: UInt64,
            _ vaultId: UInt256, 
            _ fractionData: Fraction.FractionData,
            _ curator: Address,
            _ amount: UInt256, 
            _ salePrice: UFix64,
            _ salePaymentType: Type,
            _ receiver: Address
        ) {
            self.saleId = saleId
            self.vaultId = vaultId
            self.fractionData = fractionData
            self.curator = curator
            self.amount = amount
            self.salePrice = salePrice
            self.salePaymentType = salePaymentType
            self.receiver = receiver
        }
    }

    pub resource Sale {
        
        pub let id: UInt64
        pub let vaultId: UInt256
        pub let salePrice: UFix64
        pub let amount: UInt256
        pub let salePaymentType: Type
        pub let receiver: Capability<&{FungibleToken.Receiver}>
        pub let curator: Capability<&Fraction.Collection>
        pub var discontinued: Bool
        
        init(
            id: UInt64,
            vaultId: UInt256,
            amount: UInt256,
            salePrice: UFix64,
            salePaymentType: Type,
            curator: Capability<&Fraction.Collection>,
            receiver: Capability<&{FungibleToken.Receiver}>
        ){
            self.id = id
            self.vaultId = vaultId
            self.salePrice = salePrice
            self.amount = amount
            self.salePaymentType = salePaymentType
            self.curator = curator
            self.receiver = receiver
            self.discontinued = false
        }

        pub fun purchase(buyTokens: @FungibleToken.Vault): @Fraction.Collection {

            pre {
                self.discontinued == false : "purchase:cannot buy from a discontinued sale"
                buyTokens.isInstance(self.salePaymentType) : "purchase:buyTokens is not the same typee as the salePaymentType"
                buyTokens.balance == UFix64(self.amount) * self.salePrice : "purchase:buyTokens is not enough to purchase"
            }

            let receiver = self.receiver.borrow() ?? panic("purchase:could not borrow a reference for the receiver")

            receiver.deposit(from: <- buyTokens)
            
            let fractions <- Fraction.mintFractions(
                amount: self.amount, 
                vaultId: self.vaultId, 
            )

            let listingData = ListingData(
                self.id,
                self.vaultId,
                Fraction.vaultToFractionData[self.vaultId]!,
                self.curator.address,
                self.amount,
                self.salePrice,
                self.salePaymentType,
                self.receiver.address
            )

            emit Purchase(listingData: listingData)

            self.discontinued = true
            
            return <- fractions
        }

        destroy() {
             FractionFixedPriceSale.listings[self.id] = nil
        }

    }

    pub resource interface FixedSaleCollectionPublic {
        pub fun purchaseListing(listingId: UInt64, buyTokens: @FungibleToken.Vault): @Fraction.Collection
        pub fun getIDs(): [UInt64]
    }

    pub resource FixedSaleCollection:  FixedSaleCollectionPublic {

        pub var forSale: @{UInt64: Sale}

        //Curator list a number of fractions for sale
        pub fun list(
            vaultId: UInt256, 
            curator: Capability<&Fraction.Collection>,
            amount: UInt256, 
            salePrice: UFix64,
            salePaymentType: Type,
            receiver: Capability<&{FungibleToken.Receiver}>
        ) {
            pre {
                curator.check() == true : "list:curator capability must be linked"
                receiver.check() == true : "list:receiver capability must be linked"
                curator.address == receiver.address : "list:receiver is not the curator"
            }

            if let vaultCollection = getAccount(FractionalVault.vaultAddress).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
                if let vault = vaultCollection.borrowVault(id: vaultId) {
                    assert(vault.curator.address == curator.address, message: "list:no rights to mint for the given vaultId")
                    assert(vault.auctionState == FractionalVault.State.inactive, message: "list:no listing during or after an auction")

                    let listing <- create Sale(
                        id: FractionFixedPriceSale.numOfListings,
                        vaultId: vaultId,
                        amount: amount,
                        salePrice: salePrice,
                        salePaymentType: salePaymentType,
                        curator: curator,
                        receiver: receiver
                    )
                    

                    let listingData = FractionFixedPriceSale.ListingData(
                        listing.id,
                        vaultId,
                        Fraction.vaultToFractionData[vaultId]!,
                        curator.address,
                        amount,
                        salePrice,
                        salePaymentType,
                        receiver.address
                    )

                    emit Listing(listingData: listingData)

                    FractionFixedPriceSale.listings[listing.id] = listingData

                    let oldListing <- self.forSale[FractionFixedPriceSale.numOfListings] <- listing

                    destroy oldListing


                    FractionFixedPriceSale.numOfListings = FractionFixedPriceSale.numOfListings + 1
                }
            }
        }

        //purchase
        pub fun purchaseListing(listingId: UInt64, buyTokens: @FungibleToken.Vault): @Fraction.Collection {

            let listing <- self.forSale.remove(key: listingId) ?? panic("purchaseListing:missing listing")

            let fractions <- listing.purchase(buyTokens: <- buyTokens)
            
            destroy listing
            
            return <- fractions
        }

        //cancel
        pub fun cancelListing(listingId: UInt64) {
            let listing <- self.forSale.remove(key: listingId) ?? panic("cancelListing:missing listing")
            
             let listingData = FractionFixedPriceSale.ListingData(
                listing.id,
                listing.vaultId,
                Fraction.vaultToFractionData[listing.vaultId]!,
                listing.curator.address,
                listing.amount,
                listing.salePrice,
                listing.salePaymentType,
                listing.receiver.address
            )

            emit Cancelled(listingData: listingData)
            destroy listing
        }

        pub fun getIDs(): [UInt64] {
            return self.forSale.keys
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

    pub fun getListing(saleId: UInt64): ListingData {
        return FractionFixedPriceSale.listings[saleId] ?? panic("getListing:could not get a listing for the given id")
    }

    pub init() {
        self.numOfListings = 0
        self.listings = {}

        self.CollectionPublicPath= /public/fractionFixedPriceSale
        self.CollectionStoragePath= /storage/fractionFixedPriceSale

        emit ContractInitialized()
    }

}