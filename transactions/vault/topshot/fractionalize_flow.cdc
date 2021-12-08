import TopShot from "../../../contracts/third-party/TopShot.cdc"
import FlowToken from "../../../contracts/core/FlowToken.cdc"
import FungibleToken from "../../../contracts/core/FungibleToken.cdc"
import NonFungibleToken from "../../../contracts/core/NonFungibleToken.cdc"
import FractionalVault from "../../../contracts/FractionalVault.cdc"
import Fraction from "../../../contracts/Fraction.cdc"

transaction(
    nftIds: [UInt64], 
    fractionCurator: Address,
    maxSupply: UInt256
) {
    //Collection to pull the topshot moments from
    let topshotProvider: &TopShot.Collection
    //Curator capability to mint or list fractions
    let curator: Capability<&Fraction.Collection>

    prepare(account: AuthAccount) {

        self.topshotProvider = account.borrow<&TopShot.Collection>(from: /storage/MomentCollection) 
        ?? panic("could not borrow a reference to the topshot collection")

        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        //Topshot moments to fractionalize
        let topshotCollection <- self.topshotProvider.batchWithdraw(ids: nftIds)
        
        FractionalVault.mintVault(
            collection: <- topshotCollection, 
            collectionType: Type<@TopShot.Collection>(),
            bidVault: <- FlowToken.createEmptyVault(),
            bidVaultType: Type<@FlowToken.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply
        )
    }   
}