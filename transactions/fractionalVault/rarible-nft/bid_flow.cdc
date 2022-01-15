import NonFungibleToken from "../../../contracts/core/NonFungibleToken.cdc"
import FungibleToken from "../../../contracts/core/FungibleToken.cdc"
import FlowToken from "../../../contracts/core/FlowToken.cdc"
import Fraction from "../../../contracts/Fraction.cdc"
import FractionalVault from "../../../contracts/FractionalVault.cdc"
import RaribleNFT from "../../../contracts/third-party/RaribleNFT.cdc"

// Transaction bid in a vault's auction
transaction(vaultId: UInt256, amount: UFix64) {

    //Address where the vaults are stored
    let fractionalVault: &FractionalVault.Vault
    //Vault used to kickoff the auction
    let sentVault: @FungibleToken.Vault
    //Capability for the bidder to potentially receive the underlying
    let bidder: Capability<&{NonFungibleToken.CollectionPublic}>
    //Capability for the bidder to receive a refund if their bid does not win the auction
    let refund: Capability<&{FungibleToken.Receiver}>

    prepare(signer: AuthAccount){
        let vaultAddress = FractionalVault.vaultAddress
        let collectionCapability = getAccount(vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")
        
        self.refund = signer.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)

        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.sentVault <- vaultRef.withdraw(amount: amount)
        
        self.bidder = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(RaribleNFT.collectionPublicPath)
    }

    execute {
        self.fractionalVault.bid(
            ftVault: <- self.sentVault, 
            refund: self.refund,
            bidder: self.bidder
        )
    }

}