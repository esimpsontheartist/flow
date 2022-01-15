import FractionalVault from "./FractionalVault.cdc"
import NonFungibleToken from "./core/NonFungibleToken.cdc"
import TopShot from "./third-party/TopShot.cdc"
import AllDay from "third-party/AllDay.cdc"
import MotoGPCard from "./third-party/MotoGPCard.cdc"
import RaribleNFT from "./third-party/RaribleNFT.cdc"
import Evolution from "./third-party/Evolution.cdc"
import Art from "./third-party/Art.cdc"
import ChainmonstersRewards from "third-party/ChainmonstersRewards.cdc"

/**
* A utility contract that allows one to access metadata of NFTs that live under a Vault
* by way of upcasting the reference to a specific NFT with a given id living in a vault
* of vaultId under a given address
*
* This contract get's data from a FractionalVault, and not a CoreVault
*/

pub contract VaultMetadata {
    
    // internal function to make things less repetitive
    access(self) fun getUnderlyingRef(address : Address, vaultId: UInt64, id: UInt64): auth &NonFungibleToken.NFT {
        let vaultCapability = getAccount(address).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 
        let vaultCollection = vaultCapability.borrow() 
        ?? panic("could not borrow a reference to the given capability")
        let vault = vaultCollection.borrowVault(id: vaultId) 
        ?? panic("Could not get a refernce to a vault with the given id")
        let authRef = vault.borrowUnderlyingRef(id: id)
        return authRef
    }

    //public function to get a Topshot Reference, can be used for metadata and for depositing
    pub fun getTopshotRef(address : Address, vaultId: UInt64, id: UInt64): &TopShot.NFT {
        let authRef = self.getUnderlyingRef(address: address, vaultId: vaultId, id: id)
        let topshotNFT: &TopShot.NFT = authRef as! &TopShot.NFT
        return topshotNFT
    }

    //public function to get a MotoGPCard Reference, can be used for metadata and for depositing
    pub fun getMotoGpRef(address: Address, vaultId: UInt64, id: UInt64): &MotoGPCard.NFT {
        let authRef = self.getUnderlyingRef(address: address, vaultId: vaultId, id: id)
        let motoGpNFT: &MotoGPCard.NFT = authRef as! &MotoGPCard.NFT
        return motoGpNFT
    }

    //public function to get a Rarible Reference, can be used for metadata and for depositing
    pub fun getRaribleRef(address: Address, vaultId: UInt64, nftId: UInt64): {String: String} {
        let authRef = self.getUnderlyingRef(address: address, vaultId: vaultId, id: nftId)
        let raribleNFT: &RaribleNFT.NFT = authRef as! &RaribleNFT.NFT
        let nftMetadata = raribleNFT.getMetadata()
        return nftMetadata
    }

    //public function to get an Evolution Reference, can be used for metadata and for depositing
    pub fun getEvolutionRef(address: Address, vaultId: UInt64, id: UInt64): &Evolution.NFT {
        let authRef = self.getUnderlyingRef(address: address, vaultId: vaultId, id: id)
        let evolutionNFT: &Evolution.NFT = authRef as! &Evolution.NFT
        return evolutionNFT
    }

    //public function to get an Art Reference, can be used for metadata and for depositing
    pub fun getArtRef(address: Address, vaultId: UInt64, id: UInt64): &Art.NFT {
        let authRef = self.getUnderlyingRef(address: address, vaultId: vaultId, id: id)
        let artNFT: &Art.NFT = authRef as! &Art.NFT
        return artNFT
    }

     //public function to get a Chainmonsters reward Reference, can be used for metadata and for depositing
    pub fun getChainmonstersRewardRef(address: Address, vaultId: UInt64, id: UInt64): &ChainmonstersRewards.NFT {
        let authRef = self.getUnderlyingRef(address: address, vaultId: vaultId, id: id)
        let chainmonstersNFT: &ChainmonstersRewards.NFT = authRef as! &ChainmonstersRewards.NFT
        return chainmonstersNFT
    }

    //public function to get an AllDay Reference, can be used for metadata and for depositing
    pub fun getAllDayRef(address: Address, vaultId: UInt64, id: UInt64): &AllDay.NFT {
        let authRef = self.getUnderlyingRef(address: address, vaultId: vaultId, id: id)
        let allDayNFT: &AllDay.NFT = authRef as! &AllDay.NFT
        return allDayNFT
    }

}