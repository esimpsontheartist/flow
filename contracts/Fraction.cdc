import NonFungibleToken from "./core/NonFungibleToken.cdc"
import EnumerableSet from "./EnumerableSet.cdc"

pub contract Fraction: NonFungibleToken {

    // Storage Path for a Fraction.BulkCollection resource
    pub let CollectionStoragePath: StoragePath
    //    Public Path that returns a capability to a Fraction.BulkCollectionPublic
    pub let CollectionPublicPath: PublicPath
    //  Private Path that returns a capability to Fraction.BulkCollection
    pub let CollectionPrivatePath: PrivatePath
    // Storage Path for the Fraction.Administrator resource
    pub let AdministratorStoragePath: StoragePath
    // Storage Path for the Fraction.BurnerCollection resource
    pub let BurnerStoragePath: StoragePath
    //  Public Path that returns a capability to the Fraction.BurnerCollectio
    pub let BurnerPublicPath: PublicPath


    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64
    // The API endpoint for Fraction metadata
    access(account) var baseURI: String
    
    // Resource stored in the account that deploys the contract
    // meant to be used to change the uri (in case it needs to be changed for future mints)
    pub resource Administrator {
        pub fun setUriBase(_ uri: String) {
        Fraction.baseURI = uri
    }
    }

    //Total fraction supply for a given vault id
    access(account) let fractionSupply: {UInt64: UInt256}

    // Event that emitted when the NFT contract is initialized
    pub event ContractInitialized()

    // Event that is emitted when a token is withdrawn,
    // indicating the owner of the collection that it was withdrawn from.
    //
    // If the collection is not in an account's storage, `from` will be `nil`.
    //
    pub event Withdraw(id: UInt64, from: Address?)

    // Event that is emitted when a collection is withdrawn from the FractionCollection,
    // indicating the owner of the collection that it was withdrawn from.
    //
    // If the collection is not in an account's storage, `from` will be `nil`.
    //
    pub event WithdrawCollection(id: UInt64, from: Address?)

    /**
    * Event that emitted when a token is deposited to a collection.
    * It indicates the owner of the collection that it was deposited to.
    */
    pub event Deposit(id: UInt64, to: Address?)

    // Event thats emitted when a collection is deposited to a fraction collection.
    //
    // It indicates the owner of the collection that it was deposited to.
    //
    pub event DepositCollection(id: UInt64, to: Address?)

    //An event that indicates that indicates that a set of fractions have been "retired"
    pub event FractionsRetired(ids: [UInt64])

    //An event that indicates that a certain number of fractions have been destroyed 
    pub event FractionsDestroyed(amount: Int)
    
    // Struct to represent important information about a fraction
    pub struct FractionData {
        pub let vaultId: UInt64
        pub let uri: String
        pub let curator: Address
        pub let name: String
        pub let description: String

        init(
            vaultId: UInt64,
            uri: String,
            curator: Address,
            name: String,
            description: String
        ) {
            self.vaultId = vaultId
            self.uri = uri
            self.curator = curator
            self.name = name
            self.description = description
        }
    }

    // Dictionary that maps a vaultId to the data of it's fractions
    access(account) let vaultToFractionData: {UInt64: FractionData}

    // Event emmited when fractions are minted
    pub event MintFractions(ids: [UInt64], metadata: FractionData)

    // A struct interface that allows implementors to define
    // custom behavior for `beforeTransfer` and `onBurn` operations
    pub struct interface Hook {
        access(account) fun beforeTransfer(
            from: Address?,
            to: Address?, 
            amount: UInt256, 
            vaultId: UInt64
        )

        access(account) fun onBurn(
            from: Address?,
            amount: UInt256, 
            vaultId: UInt64
        )
    }

    // Dictionary that maps vaultId => Hook
    access(account) let hooks: {UInt64: {Hook}}

    //The resource that represents the Fraction NFT
    pub resource NFT: NonFungibleToken.INFT {

        //global unique fraction ID
        pub let id: UInt64
        //Id to separate fractions by vault
        pub let vaultId: UInt64
        //Uri used to display data for a fraction
        pub let uri: String
        //Curator for the fraction
        pub let curator: Address
        //Name given to the vault/fractions
        pub let name: String
        //Description given for the vault/fractions
        pub let description: String

        init(
            id: UInt64, 
            vaultId: UInt64
        ) {
            self.id = id
            self.vaultId = vaultId
            self.curator = Fraction.vaultToFractionData[self.vaultId]!.curator
            self.name = Fraction.vaultToFractionData[self.vaultId]!.name
            self.description = Fraction.vaultToFractionData[self.vaultId]!.description
            self.uri = Fraction.vaultToFractionData[self.vaultId]!.uri
        }

        destroy(){
            if self.owner != nil {
                Fraction.hooks[self.vaultId]?.onBurn(
                    from: self.owner?.address,
                    amount: 1,
                    vaultId: self.vaultId
                )
            }
        }
    }

    //Standard NFT collectionPublic interface
    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFraction(id: UInt64): &Fraction.NFT?
    }

    //Stored by other contracts or a temporary means of moving multiple fractions
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic {
        
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            let ref = (&token as auth &NonFungibleToken.NFT) as! &Fraction.NFT
            Fraction.hooks[ref.vaultId]?.beforeTransfer(
                from: self.owner?.address, 
                to: nil, 
                amount: 1, 
                vaultId: ref.vaultId
            )
            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Fraction.NFT

            let id: UInt64 = token.id
            let vaultId: UInt64 = token.vaultId
            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token
            Fraction.hooks[vaultId]?.beforeTransfer(
                from: nil, 
                to: self.owner?.address, 
                amount: 1, 
                vaultId: vaultId
            )
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }
        

        // Returns a borrowed reference to an NFT in the collection
        // so that the caller can read data and call methods from it
        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        // Returns a borrowed reference to a Fraction
        // so that the caller can read data and call methods from it
        pub fun borrowFraction(id: UInt64): &Fraction.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &Fraction.NFT
            } else {
                return nil
            }
        }

        destroy() {
            //call beforeTransfer here
            destroy self.ownedNFTs
        }

    }

    //Functions for public references to the Bulk Collection
    pub resource interface BulkCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun getVaultIds(): [UInt64]
        pub fun getIDsByVault(vaultId: UInt64): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFraction(id: UInt64): &Fraction.NFT?
    }

    // A collection of Fraction.Collection, stored by users to manager their fractions
    pub resource BulkCollection: NonFungibleToken.CollectionPublic, BulkCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver {

        // a dictionary of Collections
        pub var ownedCollections: @{UInt64: Collection}

        //from which collection should a fraction be withdrawn from
        priv let fractionToVault: {UInt64: UInt64}
        //Dictionary that maps a vaultId to an enumerable set in order to keep track of the number
        // of fractions for a given vaultId in the collection
        priv let vaultToFractions: {UInt64: EnumerableSet.UInt64Set}

        init() {
            self.ownedCollections <- {}
            self.fractionToVault = {}
            self.vaultToFractions = {}
        }

        // withdraw an NFT with id `withdrawId` and return the resource associated with the id
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            //Find the collection from where a token should be withdrawn
            let vaultId = self.fractionToVault[withdrawID] ?? panic("withdraw:no fractions stored for this vaultId")

            // Withdraw the Fraction NFT
            let token <- self.ownedCollections[vaultId]?.withdraw(withdrawID: withdrawID)!
            //remove from the mappings
            self.fractionToVault.remove(key: withdrawID) 
            self.vaultToFractions[vaultId]?.remove(withdrawID)

            return <- token
        }    

        // Deposit a Fraction.NFT into the collection
        // the function takes care of figuring out to which collection
        // the fraction belongs to
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Fraction.NFT
            
            let vaultId = token.vaultId
            //Map the fraction's id to it's vault
            self.fractionToVault[token.id] = vaultId
            //Map the vaultId to the fraction's id
            if self.vaultToFractions[vaultId] == nil {
                self.vaultToFractions.insert(key: vaultId, EnumerableSet.UInt64Set())
            } 
            self.vaultToFractions[vaultId]?.add(token.id)
            if self.ownedCollections[vaultId] == nil {
                self.ownedCollections[vaultId] <-! Fraction.createEmptyCollection() as! @Fraction.Collection
            }

            let collectionRef = &self.ownedCollections[vaultId] as &Fraction.Collection
            collectionRef.deposit(token: <- token)
        }

        // Return all the ids in the collection
        pub fun getIDs(): [UInt64] {
            let ids: [UInt64] = []
            for collectionId in self.ownedCollections.keys {
                ids.appendAll(self.ownedCollections[collectionId]?.getIDs()!)
            }
            return ids
        }
        
        //Gets all the vaultIds in the collection
        pub fun getVaultIds(): [UInt64] {
            return self.vaultToFractions.keys
        }

        // Gets the ids associated with a collection that stores frractions for a given vaultI
        pub fun getIDsByVault(vaultId: UInt64): [UInt64] {
            let vault = self.vaultToFractions[vaultId] ?? panic("no vault for given id")
            return vault.values()
        }

        // get a reference to an NFT in the collection
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            //Find the collection from where a token should be withdrawn
            let vaultId = self.fractionToVault[id] ?? panic("withdraw:no fractions stored for this vaultId")

            // find the nft in the collection and borrow a reference
            return self.ownedCollections[vaultId]?.borrowNFT(id: id)!
        }    

        // get a reference to a Fraction.NFT in the collection
        pub fun borrowFraction(id: UInt64): &Fraction.NFT? {
            //Find the collection from where a token should be withdrawn
            let vaultId = self.fractionToVault[id] ?? panic("withdraw:no fractions stored for this vaultId")

            // find the nft in the collection and borrow a reference
            return self.ownedCollections[vaultId]?.borrowFraction(id: id)!
        }

        // get a reference to one of the collections in the Bulk collection
        // NOTE: this method is hidden from restricted references
        // as it is only meant to be used in transactions wich the owner 
        // of the bulk collection has signed on
        pub fun borrowCollection(vaultId: UInt64): &Fraction.Collection? {
            if self.ownedCollections[vaultId] != nil {
                let collectionRef = &self.ownedCollections[vaultId] as! &Fraction.Collection
                return collectionRef
            } else {
                return nil
            }
            
        }

        // withdraw a collection for a given vaultId from the BulkCollection
        // NOTE: this method is hidden from restricted references
        // as it is only meant to be used in transactions wich the owner 
        // of the bulk collection has signed on
        pub fun withdrawCollection(vaultId: UInt64): @Collection {
            let collection <- self.ownedCollections.remove(key: vaultId) ?? panic("missing collection")
            Fraction.hooks[vaultId]?.beforeTransfer(
                from: self.owner?.address, 
                to: nil, 
                amount: UInt256(collection.getIDs().length), 
                vaultId: vaultId
            )
            emit WithdrawCollection(id: vaultId, from: self.owner?.address)
            return <- collection
        }

        destroy() {
            destroy self.ownedCollections
        }
    }

    // A collection stored by the contract deployer
    // It's only utility is to facilitate other contract operations
    // that require a large number of fractions to be transferred 
    // by acting as a temporary holder of fractions (this way the user doesn't
    // have to call multiple transactions to burn their fractions, making for a better UX).
    // This resource only lets you know how many collections it stores, and the amount at
    // a given index, so it leaks no information about the underlying 
    pub resource BurnerCollection {
        priv let collections: @[Fraction.Collection]

        init() {
            self.collections <- []
        }

        //"retire" a collection by sending it to the BurnerCollection
        pub fun retire(_ collection: @Fraction.Collection) {
            let ids = collection.getIDs()
            self.collections.append(<- collection)
            emit FractionsRetired(ids: ids)
        }

        pub fun numOfCollections(): Int { 
            return self.collections.length
        }

        pub fun amountAt(_ index: Int): Int {
            return self.collections[index].getIDs().length
        }

        //A function to burn a number of fractions and free up storage space
        pub fun burnFractions(_ amount: Int) {
            pre {
                self.collections.length > 0 : "burnFractions:no fractions to burn"
            }
            
            //keep track of the number of fractions that have been burned
            var i = 0
            while true {
                let ids = self.collections[0].getIDs()
                for id in ids {
                    let fraction <-  self.collections[0].withdraw(withdrawID: id)
                    destroy fraction
                    i = i + 1
                    if i == amount {
                        break
                    }
                }

                //break if we have reached the amount that we wanted to burn
                if i == amount {
                    break
                }

                //destroy a collection that has just been emptied
                if self.collections[0].getIDs().length == 0 {
                    destroy <- self.collections.removeFirst()
                }

                //break if there are no more collections to burn from
                if self.collections.length == 0 {
                    break
                }
                
            }
            
            emit FractionsDestroyed(amount: i)
        }

        destroy() {
            destroy self.collections
        }
    }

    // public function that anyone can call to create a new empty collection
    // NOTE: this collection is defined in order for Fractions to follow the NFT 
    // standard. For general uses and interaction with the Fractional Protocol
    // use createBulkCollection()
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }
    
    // public function that anyone can call to create a new empty bulk collection
    pub fun createBulkCollection(): @BulkCollection {
        return <- create BulkCollection()
    }

    // function to mint a group of fractions corresponding to a vault
    // can only be called by contracts in the account that deployed 
    // this contract
    access(account) fun mintFractions(
        amount: UInt256, 
        vaultId: UInt64
    ): @Collection {

        let newCollection <- create Collection()

        var ids: [UInt64] = []
        var i: UInt256 = 0 
        while i < amount {
            newCollection.deposit(token: <- create NFT(
                    id: Fraction.totalSupply, 
                    vaultId: vaultId
                )
            )
            ids.append(Fraction.totalSupply)
            self.totalSupply = self.totalSupply + 1
            i = i + 1
        }

        let metadata = FractionData(
            vaultId: vaultId,
            uri: self.vaultToFractionData[vaultId]!.uri,
            curator: self.vaultToFractionData[vaultId]!.curator,
            name: self.vaultToFractionData[vaultId]!.name,
            description: self.vaultToFractionData[vaultId]!.description,
        )

        emit MintFractions(ids: ids, metadata: metadata)

        //Add a call to transfer delegate

        if self.fractionSupply[vaultId] == nil {
            self.fractionSupply[vaultId] = amount
        } 
        else {
            self.fractionSupply[vaultId] = self.fractionSupply[vaultId]! + amount
        }
        
        return <- newCollection
    }

    //Get the total fraction suppkly for a given vaultId
    pub fun getFractionSupply(vaultId: UInt64): UInt256 {
        return self.fractionSupply[vaultId] ?? 0
    }

    init() {
        self.CollectionPublicPath = /public/fractionalCollection
        self.CollectionPrivatePath = /private/fractionalCollection
        self.CollectionStoragePath = /storage/fractionalCollection
        self.AdministratorStoragePath = /storage/fractionAdmin
        self.BurnerStoragePath = /storage/fractionBurner
        self.BurnerPublicPath = /public/fractionBurner

        self.totalSupply = 0
        //this can be set at contract creation time
        self.baseURI = ""

        self.fractionSupply = {}
        self.vaultToFractionData = {}
        self.hooks = {}

        self.account.save<@Fraction.Administrator>( <- create Administrator(), to: self.AdministratorStoragePath)
        self.account.save<@Fraction.BurnerCollection>(<- create BurnerCollection(), to: self.BurnerStoragePath)
        self.account.link<&Fraction.BurnerCollection>(self.BurnerPublicPath, target: self.BurnerStoragePath)
        self.account.save<@Fraction.BulkCollection>(<- self.createBulkCollection(), to: self.CollectionStoragePath)
        self.account.link<&{Fraction.BulkCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)
        self.account.link<&Fraction.BulkCollection>(self.CollectionPrivatePath, target: self.CollectionStoragePath)

        emit ContractInitialized()
    }
}
