import WrappedCollection from "../../contracts/lib/WrappedCollection.cdc"
import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import FractionalVault from "../../contracts/FractionalVault.cdc"


pub struct WNFT {
    pub let id: UInt64
    pub let address: Address
    pub let nftType: Type
    pub let collectionPath: PublicPath

    init(id: UInt64, address: Address, collectionPath: PublicPath, nftType: Type) {
        self.id = id
        self.address = address
        self.nftType = nftType
        self.collectionPath = collectionPath
    }
}
// This scripts returns a reference to one of the NFTs in a vault's collection
pub fun main(vaultId: UInt256, itemUUID: UInt64): WNFT? {

    let vaultAddress = FractionalVault.vaultAddress
    //Vault that will be returned
    if let vaultCollection = getAccount(vaultAddress).getCapability<&FractionalVault.VaultCollection{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath).borrow() {
        if let vault = vaultCollection.borrowVault(id: vaultId) {
            let underlyingCollection = vault.borrowUnderlying()
            let underlyingWNFT = underlyingCollection.borrowWNFT(id: itemUUID)
            let id = underlyingWNFT.borrowNFT().id
            return WNFT(id: id, address: underlyingWNFT.getAddress(), collectionPath: underlyingWNFT.getCollectionPath() ,nftType: underlyingWNFT.nestedType())
        }
    }
    return nil

}