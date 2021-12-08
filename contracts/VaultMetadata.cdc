import FractionalVault from "./FractionalVault.cdc"
import NonFungibleToken from "./core/NonFungibleToken.cdc"
import TopShot from "./third-party/TopShot.cdc"
import MotoGPCard from "./third-party/MotoGPCard.cdc"
import RaribleNFT from "./third-party/RaribleNFT.cdc"
import Evolution from "./third-party/Evolution.cdc"
import Art from "./third-party/Art.cdc"
import ChainmonstersRewards from "third-party/ChainmonstersRewards.cdc"

pub contract VaultMetadata {
    
    // internal function to make things less repetitive
    access(self) fun getVaultRef(vaultId: UInt256): auth &NonFungibleToken.Collection {
        let vaultAddress = FractionalVault.vaultAddress
        let vaultCapability = getAccount(vaultAddress).getCapability<&{FractionalVault.VaultCollectionPublic}>(FractionalVault.VaultPublicPath) 
        let vaultCollection = vaultCapability.borrow() 
        ?? panic("could not borrow a reference to the given capability")
        let vault = vaultCollection.borrowVault(id: vaultId) 
        ?? panic("Could not get a refernce to a vault with the given id")
        let authRef = vault.borrowCollectionRef()
        return authRef
    }

    //public function to get a Topshot Reference, can be used for metadata and for depositing
    pub fun getTopshotRef(vaultId: UInt256): &{TopShot.MomentCollectionPublic} {
        let authRef = self.getVaultRef(vaultId: vaultId)
        let topshotCollection: &TopShot.Collection = authRef as! &TopShot.Collection
        let topshotPublicCollection: &{TopShot.MomentCollectionPublic} = topshotCollection as &{TopShot.MomentCollectionPublic}
        return topshotPublicCollection
    }

    //public function to get a MotoGPCard Reference, can be used for metadata and for depositing
    pub fun getMotoGpRef(vaultId: UInt256): &{MotoGPCard.ICardCollectionPublic} {
        let authRef = self.getVaultRef(vaultId: vaultId)
        let motoGpCollection: &MotoGPCard.Collection = authRef as! &MotoGPCard.Collection
        let motoGpPublicCollection: &{MotoGPCard.ICardCollectionPublic} = motoGpCollection as &{MotoGPCard.ICardCollectionPublic}
        return motoGpPublicCollection
    }

    //public function to get a Rarible Reference, can be used for metadata and for depositing
    pub fun getRaribleRef(vaultId: UInt256, nftId: UInt64): {String: String} {
        let authRef = self.getVaultRef(vaultId: vaultId)
        let raribleNFTCollection: &RaribleNFT.Collection = authRef as! &RaribleNFT.Collection
        let nftMetadata = raribleNFTCollection.getMetadata(id: nftId)
        return nftMetadata
    }

    //public function to get an Evolution Reference, can be used for metadata and for depositing
    pub fun getEvolutionRef(vaultId: UInt256): &{Evolution.EvolutionCollectionPublic} {
        let authRef = self.getVaultRef(vaultId: vaultId)
        let evolutionCollection: &Evolution.Collection = authRef as! &Evolution.Collection
        let evolutionPublicCollection: &{Evolution.EvolutionCollectionPublic} = evolutionCollection as &{Evolution.EvolutionCollectionPublic}
        return evolutionPublicCollection
    }

    //public function to get an Art Reference, can be used for metadata and for depositing
    pub fun getArtRef(vaultId: UInt256): &{Art.CollectionPublic} {
        let authRef = self.getVaultRef(vaultId: vaultId)
        let artCollection: &Art.Collection = authRef as! &Art.Collection
        let artPublicCollection: &{Art.CollectionPublic} = artCollection as &{Art.CollectionPublic}
        return artPublicCollection
    }

     //public function to get a Chainmonsters reward Reference, can be used for metadata and for depositing
    pub fun getChainmonstersRewardRef(vaultId: UInt256): &{ChainmonstersRewards.ChainmonstersRewardCollectionPublic} {
        let authRef = self.getVaultRef(vaultId: vaultId)
        let chainmonstersRewardCollection: &ChainmonstersRewards.Collection = authRef as! &ChainmonstersRewards.Collection
        let chainmonstersRewardPublicCollection: &{ChainmonstersRewards.ChainmonstersRewardCollectionPublic} = chainmonstersRewardCollection as &{ChainmonstersRewards.ChainmonstersRewardCollectionPublic}
        return chainmonstersRewardPublicCollection
    }



}