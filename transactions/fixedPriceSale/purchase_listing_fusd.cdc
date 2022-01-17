import FUSD from "../../contracts/core/FUSD.cdc"
import FungibleToken from "../../contracts/core/FungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FixedPriceSale from "../../contracts/FixedPriceSale.cdc"

transaction(
    listingId: UInt64,
    seller: Address,
    amount: UFix64
) {

    //Collection to carry out the sale
    let fixedSaleCollection: &{FixedPriceSale.FixedSaleCollectionPublic}
    //Payment for the listing
    let payment: @FungibleToken.Vault
    //Capability to receive the fractions from the listing
    let fractionCollection: &{Fraction.BulkCollectionPublic}

    prepare(signer: AuthAccount){
        self.fixedSaleCollection = getAccount(seller).getCapability<&{FixedPriceSale.FixedSaleCollectionPublic}>(FixedPriceSale.CollectionPublicPath).borrow()
        ?? panic("could not borrow a reference for the fixed price sale")

        let vaultRef = signer.borrow<&FUSD.Vault>(from: /storage/fusdVault)
        ?? panic("Could not borrow reference to the owner's Vault!")

        self.payment <- vaultRef.withdraw(amount: amount)

        self.fractionCollection = signer.getCapability<&{Fraction.BulkCollectionPublic}>(Fraction.CollectionPublicPath).borrow()
        ?? panic("Could not borrow a reference to the Fraction collection")
    }

    execute {
        let fractions <- self.fixedSaleCollection.purchaseListing(
            listingId: listingId,
            buyTokens: <- self.payment
        )

        for id in fractions.getIDs() {
            self.fractionCollection.deposit(token: <- fractions.withdraw(withdrawID: id))
        }
        
        destroy fractions
        
    }
}