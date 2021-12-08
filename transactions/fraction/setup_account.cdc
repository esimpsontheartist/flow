import NonFungibleToken from "../../contracts/core/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"

// This transaction configure an account to hold fractions

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&Fraction.Collection>(from: Fraction.CollectionStoragePath) == nil {
             // create a new empty collection
            let collection <- Fraction.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: Fraction.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&Fraction.Collection{NonFungibleToken.CollectionPublic, Fraction.CollectionPublic}>
            (Fraction.CollectionPublicPath, target: Fraction.CollectionStoragePath)

            // create a private capability for the collection
            signer.link<&Fraction.Collection>(Fraction.CollectionPrivatePath, target: Fraction.CollectionStoragePath)
        }
    }
}