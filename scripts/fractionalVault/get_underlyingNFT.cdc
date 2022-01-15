import Basket from "../../contracts/Basket.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"

pub struct NFT {
    pub let id: UInt64

    init(id: UInt64) {
        self.id = id
    }
}
// This scripts returns a reference to one of the NFTs in a vault's collection
pub fun main(address: Address, vaultId: UInt64, itemUUID: UInt64): NFT? {

    //Vault that will be returned
    if let vaultCollection = getAccount(address).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            let underlyingCollection = vault.borrowUnderlying()
            let underlyingNFT = underlyingCollection.borrowNFT(id: itemUUID)
            return NFT(id: underlyingNFT.id)
        }
    }
    return nil

}