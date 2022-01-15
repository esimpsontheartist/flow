import CoreVault from "../../contracts/CoreVault.cdc"

// This transaction configures an account to hold core vaults

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&CoreVault.VaultCollection>(from: CoreVault.CollectionStoragePath) == nil {
             // create a new empty collection
            let collection <- CoreVault.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: CoreVault.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&CoreVault.VaultCollection{CoreVault.CollectionPublic}>(CoreVault.CollectionPublicPath, target: CoreVault.CollectionStoragePath)
        }
    }
}