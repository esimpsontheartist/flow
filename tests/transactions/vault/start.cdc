import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"
import WrappedCollection from "../../contracts/WrappedCollection.cdc"

// A transaction to kickoff an auction
transaction(vaultId: UInt256, amount: UFix64) {

    //Address where the vaults are stored
    let fractionalVault: &FractionalVault.Vault
    //Vault used to kickoff the auction
    let sentVault: @FungibleToken.Vault

    let bidder: Capability<&{WrappedCollection.WrappedCollectionPublic}>

    prepare(signer: AuthAccount){
        let vaultAddress = FractionalVault.vaultAddress
        let collectionCapability = getAccount(vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")
            
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.sentVault <- vaultRef.withdraw(amount: amount)

        self.bidder = signer.getCapability<&{WrappedCollection.WrappedCollectionPublic}>(WrappedCollection.WrappedCollectionPublicPath)
    }

    execute {
        self.fractionalVault.start(flowVault: <- self.sentVault, bidder: self.bidder)
    }

}