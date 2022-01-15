import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import Modules from "../../contracts/Modules.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"
import FixedPriceSale from "../../contracts/FixedPriceSale.cdc"

transaction(
    vaultId: UInt64,
    amount: UInt256,
    salePrice: UFix64
    
) {
    //Collection to carry out the sale
    let fixedSaleCollection: &FixedPriceSale.FixedSaleCollection
    //A capability to receive Flow for a sale
    let receiver: Capability<&{FungibleToken.Receiver}>
    //A capability to the curator's fractions
    let curator: Capability<&{Modules.CappedMinterCollection}>
    //
    prepare(signer: AuthAccount){
        self.fixedSaleCollection = signer.borrow<&FixedPriceSale.FixedSaleCollection>(from: FixedPriceSale.CollectionStoragePath)
        ?? panic("could not borrow a reference for the fixed price sale")

        self.curator = signer.getCapability<&{Modules.CappedMinterCollection}>(FractionalVault.MinterPrivatePath)

        self.receiver = signer.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    }

    execute {

        self.fixedSaleCollection.list(
            vaultId: vaultId,
            minter: self.curator,
            amount: amount,
            salePrice: salePrice,
            salePaymentType:  Type<@FlowToken.Vault>(),
            receiver: self.receiver
        )
    }
}