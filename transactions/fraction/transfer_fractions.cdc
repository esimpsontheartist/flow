import NonFungibleToken from "../../contracts/core/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"

// This transaction transfers a Fraction from one account to another

transaction(recipient: Address, withdrawIDs: [UInt64]) {

    let collectionRef: &Fraction.BulkCollection
    prepare(signer: AuthAccount) {

        // borrow a reference to the signer's Fraction
        self.collectionRef = signer.borrow<&Fraction.BulkCollection>(from: Fraction.CollectionStoragePath)
            ?? panic("Could not borrow a reference to the owner's collection")

    }

    execute {

         // get the recipients public account object
        let recipient = getAccount(recipient)
        
        // borrow a public reference to the receivers collection
        let receiverRef = recipient.getCapability(Fraction.CollectionPublicPath).borrow<&{NonFungibleToken.CollectionPublic}>()!

        let ids = self.collectionRef.getIDs()
        let length = ids.length
        for id in withdrawIDs {
            // withdraw the NFT from the owner's collection
            let nft <- self.collectionRef.withdraw(withdrawID: id)

            // Deposit the NFT in the recipient's collection
            receiverRef.deposit(token: <-nft)
        }  

    }
}
