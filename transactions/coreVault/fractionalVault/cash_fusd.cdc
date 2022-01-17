import NonFungibleToken from "../../../contracts/core/NonFungibleToken.cdc"
import FungibleToken from "../../../contracts/core/FungibleToken.cdc"
import Fraction from "../../../contracts/Fraction.cdc"
import FractionalVault from "../../../contracts/FractionalVault.cdc"

// a transaction to call the cash() function 
// in order to swap fractions for the FUSD proceeds of an auction
transaction(address: Address, vaultId: UInt64) {

    //Reference to the signers Fraction collection
    let usersCollection: &Fraction.BulkCollection
    //Vault for which proceeds will be cashed
    let fractionalVault: &{FractionalVault.PublicVault}
    //Capability to deposit the proceeds
    let vaultCap: Capability<&{FungibleToken.Receiver}>

    prepare(signer: AuthAccount){

        let collectionCapability = getAccount(address).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")
            
        self.usersCollection = signer.borrow<&Fraction.BulkCollection>(from: Fraction.CollectionStoragePath)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.vaultCap = signer.getCapability<&{FungibleToken.Receiver}>(/public/fusdReceiver)

    }

    execute {

        self.fractionalVault.cash(collection: self.usersCollection, collector: self.vaultCap)
    }

}