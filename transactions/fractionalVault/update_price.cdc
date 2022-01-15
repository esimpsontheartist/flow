import Fraction from "../../contracts/Fraction.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

// Transaction to update the bid for a set of fractions

transaction(vaultId: UInt256, startId: UInt64, amount: UInt256, newPrice: UFix64) {

    let fractions: &Fraction.Collection
    
    prepare(signer: AuthAccount) {
        self.fractions = signer.borrow<&Fraction.Collection>(from: Fraction.CollectionStoragePath) ?? panic("Could not borrow a refercen to the collection of fractions")
    }

    execute {
        FractionalVault.updateFractionPrice(vaultId, collection: self.fractions, startId: startId, amount: amount, new: newPrice)
    }
}
