import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FractionFixedPriceSale from "../../contracts/FractionFixedPriceSale.cdc"

transaction(
    listingId: UInt64,
    seller: Address,
    amount: UFix64
) {

    //Collection to carry out the sale
    let fixedSaleCollection: &{FractionFixedPriceSale.FixedSaleCollectionPublic}
    //Payment for the listing
    let payment: @FungibleToken.Vault
    //Capability to receive the fractions from the listing
    let fractionCollection: &{Fraction.CollectionPublic}

    prepare(signer: AuthAccount){
        self.fixedSaleCollection = getAccount(seller).getCapability<&{FractionFixedPriceSale.FixedSaleCollectionPublic}>(FractionFixedPriceSale.CollectionPublicPath).borrow()
        ?? panic("could not borrow a reference for the fixed price sale")

        let vaultRef = signer.borrow<&FUSD.Vault>(from: /storage/fusdVault)
        ?? panic("Could not borrow reference to the owner's Vault!")

        self.payment <- vaultRef.withdraw(amount: amount)

        self.fractionCollection = signer.getCapability<&{Fraction.CollectionPublic}>(Fraction.CollectionPublicPath).borrow()
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
 