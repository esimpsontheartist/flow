import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

// a transaction to call the cash() function 
// in order to swap fractions for the FLOW proceeds of an auction
transaction(vaultId: UInt256) {

    //Reference to the signers Fraction collection
    let usersCollection: &Fraction.Collection
    //Address where the vaults are stored
    let fractionalVault: &FractionalVault.Vault
    //Vault used to kickoff the auction
    let sentCollection: @NonFungibleToken.Collection

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

    }

    execute {
        let fractionIds = self.usersCollection.vaultToFractions[vaultId]!.values()

        if fractionIds.length == 0 {
            return
        }

        for id in fractionIds {
            self.sentCollection.deposit(token: <- self.usersCollection.withdraw(withdrawID: id))
        }

        self.fractionalVault.cash(<- self.sentCollection)
    }

}