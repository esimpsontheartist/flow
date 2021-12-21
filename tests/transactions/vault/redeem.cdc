import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"
import WrappedCollection from "../../contracts/WrappedCollection.cdc"

// a transaction to call the redeem() function in order to receive the underlying after
transaction(vaultId: UInt256, amount: UInt256) {

    //Reference to the signers Fraction collection
    let usersCollection: &Fraction.BulkCollection
    //Address where the vaults are stored
    let fractionalVault: &FractionalVault.Vault
    //Capability that places the bids
    let redeemer: Capability<&{NonFungibleToken.CollectionPublic}>

    prepare(signer: AuthAccount){
        let vaultAddress = FractionalVault.vaultAddress
        let collectionCapability = getAccount(vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")
            
        self.usersCollection = signer.borrow<&Fraction.BulkCollection>(from: Fraction.CollectionStoragePath)
            ?? panic("Could not borrow reference to the owner's Fraction collection!")

        self.redeemer = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(WrappedCollection.CollectionPublicPath)
    }

    execute {
        self.fractionalVault.redeem(
            collection: self.usersCollection, 
            amount: amount, 
            redeemer: self.redeemer
        )
    }

}