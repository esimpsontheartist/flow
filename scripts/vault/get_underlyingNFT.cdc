import WrappedCollection from "../../contracts/lib/WrappedCollection.cdc"
import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"


pub struct NFT {
    pub let id: UInt64

    init(id: UInt64) {
        self.id = id
    }
}
// This scripts returns a reference to one of the NFTs in a vault's collection
pub fun main(vaultId: UInt256, itemUUID: UInt64): NFT? {

    let vaultAddress = FractionalVault.vaultAddress
    //Vault that will be returned
    if let vaultCollection = getAccount(vaultAddress).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            let underlyingCollection = vault.borrowUnderlying()
            let underlyingNFT = underlyingCollection.borrowNFT(id: itemUUID)
            return NFT(id: underlyingNFT.id)
        }
    }
    return nil

}