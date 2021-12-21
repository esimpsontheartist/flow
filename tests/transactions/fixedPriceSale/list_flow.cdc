import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import Fraction from "../../contracts/Fraction.cdc"
import FractionFixedPriceSale from "../../contracts/FractionFixedPriceSale.cdc"

transaction(
    vaultId: UInt256,
    amount: UInt256,
    salePrice: UFix64
    
) {
    //Collection to carry out the sale
    let fixedSaleCollection: &FractionFixedPriceSale.FixedSaleCollection
    //A capability to receive Flow for a sale
    let receiver: Capability<&{FungibleToken.Receiver}>
    //A capability to the curator's fractions
    let curator: Capability<&Fraction.BulkCollection>
    //
    prepare(signer: AuthAccount){
        self.fixedSaleCollection = signer.borrow<&FractionFixedPriceSale.FixedSaleCollection>(from: FractionFixedPriceSale.CollectionStoragePath)
        ?? panic("could not borrow a reference for the fixed price sale")

        self.curator = signer.getCapability<&Fraction.BulkCollection>(Fraction.CollectionPrivatePath)

        self.receiver = signer.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    }

    execute {

        self.fixedSaleCollection.list(
            vaultId: vaultId,
            curator: self.curator,
            amount: amount,
            salePrice: salePrice,
            salePaymentType:  Type<@FlowToken.Vault>(),
            receiver: self.receiver
        )
    }
}