import NonFungibleToken from "../../contracts/core/NonFungibleToken.cdc"
import FungibleToken from "../../contracts/core/FungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

// a transaction to call the cash() function 
// in order to swap fractions for the FLOW proceeds of an auction
transaction(vaultId: UInt256, fractionIds: [UInt64]) {

    //Reference to the signers Fraction collection
    let usersCollection: &Fraction.Collection
    //Vault for which proceeds will be cashed
    let fractionalVault: &FractionalVault.Vault
    //Vault used to kickoff the auction
    let sentCollection: @NonFungibleToken.Collection
    //Capability to deposit the proceeds
    let vaultCap: Capability<&{FungibleToken.Receiver}>

    prepare(signer: AuthAccount){
        let vaultAddress = FractionalVault.vaultAddress
        let collectionCapability = getAccount(vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")
            
        self.usersCollection = signer.borrow<&Fraction.Collection>(from: Fraction.CollectionStoragePath)
            ?? panic("Could not borrow reference to the owner's Vault!")


        self.sentCollection <- Fraction.createEmptyCollection()

        self.vaultCap = signer.getCapability<&{FungibleToken.Receiver}>(/public/fusdReceiver)

    }

    execute {

        if fractionIds.length == 0 {
            panic("No fractions to cash")
        }

        for id in fractionIds {
            self.sentCollection.deposit(token: <- self.usersCollection.withdraw(withdrawID: id))
        }

        self.fractionalVault.cash(collection: <- self.sentCollection, collector: self.vaultCap)
    }

}