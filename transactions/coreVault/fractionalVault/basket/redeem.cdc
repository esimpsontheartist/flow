import NonFungibleToken from "../../../../contracts/core/NonFungibleToken.cdc"
import Fraction from "../../../../contracts/Fraction.cdc"
import FractionalVault from "../../../../contracts/FractionalVault.cdc"
import Basket from "../../../../contracts/Basket.cdc"

// a transaction to call the redeem() function in order to receive the underlying after
transaction(address: Address, vaultId: UInt64, amount: UInt256) {

    let usersCollection: &Fraction.BulkCollection
    //Address where the vaults are stored
    let fractionalVault: &{FractionalVault.PublicVault}
    //Capability that places the bids
    let redeemer: Capability<&{NonFungibleToken.CollectionPublic}>

    prepare(signer: AuthAccount){
        let collectionCapability = getAccount(address).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")
            
        self.usersCollection = signer.borrow<&Fraction.BulkCollection>(from: Fraction.CollectionStoragePath)
            ?? panic("Could not borrow reference to the owner's Fraction collection!")

        self.redeemer = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(Basket.CollectionPublicPath)
    }

    execute {
        self.fractionalVault.redeem(
            collection: self.usersCollection, 
            redeemer: self.redeemer
        )
    }

}