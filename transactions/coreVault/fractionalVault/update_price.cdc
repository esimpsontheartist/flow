import Fraction from "../../../contracts/Fraction.cdc"
import FractionalVault from "../../../contracts/FractionalVault.cdc"

// Transaction to update the bid for a set of fractions
transaction(
    address: Address,
    vaultId: UInt64, 
    newPrice: UFix64
) {

    //Collection that stores the vault
    let fractionalVault: &{FractionalVault.PublicVault}

    let fractions: &Fraction.BulkCollection
    
    prepare(signer: AuthAccount) {
        let collectionCapability = getAccount(address).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 

        let vaultCollection = collectionCapability.borrow() 
            ?? panic("could not borrow a reference to the given capability")
            
        self.fractionalVault = vaultCollection.borrowVault(id: vaultId) 
            ?? panic("Could not get a refernce to a vault with the given id")

        self.fractions = signer.borrow<&Fraction.BulkCollection>(from: Fraction.CollectionStoragePath) ?? panic("Could not borrow a refercen to the collection of fractions")
    }

    execute {
        self.fractionalVault.updateUserPrice(collection: self.fractions, new: newPrice)
    }
}