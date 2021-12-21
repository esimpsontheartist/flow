import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import Fraction from "./Fraction.cdc"

/**
* The base Vault that defines a 'Vault' resource that has the following core functions
* - pull() allows other contracts in the account to define ways to handle NFT references)
* - end()  allows other contracts in the account to define ways to handle buyout Logic)
* - mint() allows a vault, and other resources and contracts inside of the Fractional account
* to call it in order to mint Fractions
*/

pub contract CoreVault {
    
    pub event ContractInitialized()

    pub event VaultMinted(
        id: UInt64, 
        curator: Address,
        underlyingType: Type
    );

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath

    pub resource Vault {
        
        //Capability of the curator/creator of this vault
        pub let curator: Capability<&Fraction.BulkCollection>
        //Underlying NFTs being held
        access(contract) var underlying: @NonFungibleToken.Collection
        //Type of collection that was deposited
        pub let underlyingType: Type

        init(
            curator: Capability<&Fraction.BulkCollection>,
            underlying: @NonFungibleToken.Collection,
            underlyingType: Type
        ){
            pre {
                curator.check() == true : "init:curator capability must be linked"
            }
            
            self.underlying <- underlying
            self.underlyingType = underlyingType
            self.curator = curator

            emit VaultMinted(
                id: self.uuid,
                curator: self.curator.address,
                underlyingType: self.underlyingType
            )
        }

        access(account) fun mint(amount: UInt256): @Fraction.Collection {
            return <- Fraction.mintFractions(amount: amount, vaultId: self.uuid)
        }

        /**
        * The pull() function in Flow doesn't remove the NFT from the collectio/vault
        * instead it provides an auth reference to a given NFT, which can be freely
        * upcasted to its original type, and thus can be used in other contracts/modules
        * for "renting" purposes. The only case in which a full reference is not a good
        * replacement for actually removing the resource is those in which the NFT
        * must be deposited somewhere else, or burned, which compromise the security of
        * the fractional vault.
        */
        access(account) fun pull(id: UInt64): auth &NonFungibleToken.NFT {
            return &self.underlying.ownedNFTs[id] as auth &NonFungibleToken.NFT
        }
        
        
        // A function to withdraw the underlying Collection from the Vault
        access(account) fun end(): @NonFungibleToken.Collection {
            //Use the createEmptyCollection to simply swap out the nested underlying resource
            var collection <- Fraction.createEmptyCollection()
            self.underlying <-> collection
            return <- collection
        }

        pub fun borrowPublicCollection(): &{NonFungibleToken.CollectionPublic} {
            return &self.underlying as &{NonFungibleToken.CollectionPublic}
        }

        destroy() {
            pre {
                self.underlying.getIDs().length == 0 : "destroy:cannot destroy a vault that still holds NFTs"
            }
            destroy self.underlying
        }
    }

    //Public facing resource interface for a collection that holds vaults
    pub resource interface CollectionPublic {
        pub fun depositVault(vault: @CoreVault.Vault)
		pub fun getIDs(): [UInt64]
		pub fun borrowVault(id: UInt64): &CoreVault.Vault
    }
    
    //Resource events
    pub event VaultDeposited(id: UInt64, to: Address?)
    pub event VaultWithdrawn(id: UInt64, from: Address?)

    //A collection to be held by Modules and other contracts in this account
    pub resource VaultCollection: CollectionPublic { 

        //A dictionary of the Vaults this collection holds
        pub let vaults: @{UInt64: CoreVault.Vault}

        init() {
            self.vaults <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @CoreVault.Vault {
            let vault <- self.vaults.remove(key: withdrawID) ?? panic("withdraw:missing vault")
            emit VaultWithdrawn(id: vault.uuid, from: self.owner?.address)
            return <- vault
        }

        // takes a vault and adds it to the vault dictionary
        pub fun depositVault(vault: @CoreVault.Vault) {
            let vault <- vault 

            let id: UInt64 = vault.uuid

            let oldVault <- self.vaults[id] <- vault

            emit VaultDeposited(id: id, to: self.owner?.address)

            destroy oldVault
        }

        // getIDs returns an array of the IDs that are in the collection
		pub fun getIDs(): [UInt64] {
			return self.vaults.keys
		}

        pub fun borrowVault(id: UInt64): &CoreVault.Vault {
            return &self.vaults[id] as &CoreVault.Vault
        }

        destroy(){
            destroy self.vaults
        }
    }

    pub fun createEmptyCollection(): @VaultCollection {
        return <- create VaultCollection()
    }

    init() {
        self.CollectionStoragePath = /storage/fractionalVaults
        self.CollectionPrivatePath = /private/fractionalVaults
        self.CollectionPublicPath = /public/fractionalVaults

        self.account.save<@CoreVault.VaultCollection>(<- self.createEmptyCollection(), to: CoreVault.CollectionStoragePath)
		self.account.link<&{CoreVault.CollectionPublic}>(CoreVault.CollectionPublicPath, target: CoreVault.CollectionStoragePath)
		self.account.link<&CoreVault.VaultCollection>(CoreVault.CollectionPrivatePath, target: CoreVault.CollectionStoragePath)

        emit ContractInitialized()	
        
    }
 }