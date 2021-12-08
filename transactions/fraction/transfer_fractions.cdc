import NonFungibleToken from "../../contracts/core/NonFungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"

// This transaction transfers a Fraction from one account to another

transaction(recipient: Address, withdrawIDs: [UInt64]) {

    let transferNFTs: @NonFungibleToken.Collection

    prepare(signer: AuthAccount) {

        self.transferNFTs <- Fraction.createEmptyCollection()

        // borrow a reference to the signer's Fraction
        let collectionRef = signer.borrow<&Fraction.Collection>(from: Fraction.CollectionStoragePath)
            ?? panic("Could not borrow a reference to the owner's collection")

         // borrow a public reference to the receivers collection
        //let depositRef = recipient.getCapability(Fraction.CollectionPublicPath)!.borrow<&{NonFungibleToken.CollectionPublic}>()!

        for id in withdrawIDs {
            // withdraw the NFT from the owner's collection
            let nft <- collectionRef.withdraw(withdrawID: id)

            // Deposit the NFT in the recipient's collection
            self.transferNFTs.deposit(token: <-nft)
        }  

    }

    execute {
        // get the recipients public account object
        let recipient = getAccount(recipient)
        
        // borrow a public reference to the receivers collection
        let receiverRef = recipient.getCapability(Fraction.CollectionPublicPath).borrow<&{NonFungibleToken.CollectionPublic}>()!

        let ids = self.transferNFTs.getIDs()

        for id in ids {
            
            // withdraw the NFT from the owner's collection
            let nft <- self.transferNFTs.withdraw(withdrawID: id)

            receiverRef.deposit(token: <- nft)
        }

        destroy self.transferNFTs

    }
}
