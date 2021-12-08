import FUSD from "../../contracts/core/FUSD.cdc"
import FungibleToken from "../../contracts/core/FungibleToken.cdc"
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
    //A capability to
    let curator: Capability<&Fraction.Collection>
    prepare(signer: AuthAccount){
        self.fixedSaleCollection = signer.borrow<&FractionFixedPriceSale.FixedSaleCollection>(from: FractionFixedPriceSale.CollectionStoragePath)
        ?? panic("could not borrow a reference for the fixed price sale")

        self.curator = signer.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)

        self.receiver = signer.getCapability<&{FungibleToken.Receiver}>(/public/fusdReceiver)
    }

    execute {

        self.fixedSaleCollection.list(
            vaultId: vaultId,
            curator: self.curator,
            amount: amount,
            salePrice: salePrice,
            salePaymentType:  Type<@FUSD.Vault>(),
            receiver: self.receiver
        )
    }
}