import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import WrappedCollection from "../../contracts/lib/WrappedCollection.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

// This transaction configure an account to hold a vault

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&FractionalVault.VaultCollection>(from: FractionalVault.VaultStoragePath) == nil {
             // create a new empty collection
            let collection <- FractionalVault.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: FractionalVault.VaultStoragePath)

            // create a public capability for the collection
            signer.link<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath, target: FractionalVault.VaultStoragePath)
        }
    }
}