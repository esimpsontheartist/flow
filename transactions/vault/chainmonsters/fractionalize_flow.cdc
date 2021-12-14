import ChainmonstersRewards from "../../../contracts/third-party/ChainmonstersRewards.cdc"
import FlowToken from "../../../contracts/core/FlowToken.cdc"
import FungibleToken from "../../../contracts/core/FungibleToken.cdc"
import NonFungibleToken from "../../../contracts/core/NonFungibleToken.cdc"
import FractionalVault from "../../../contracts/FractionalVault.cdc"
import Fraction from "../../../contracts/Fraction.cdc"

transaction(
    nftIds: [UInt64], 
    fractionCurator: Address,
    maxSupply: UInt256,
    name: String, 
    description: String
) {
    //Collection to pull the MotoGP Cards from
    let cmRewardProvider: &ChainmonstersRewards.Collection
    //Curator capability to mint or list fractions
    let curator: Capability<&Fraction.Collection>

    prepare(account: AuthAccount) {

        self.cmRewardProvider = account.borrow<&ChainmonstersRewards.Collection>(from: /storage/ChainmonstersRewardCollection) 
        ?? panic("could not borrow a reference to the MotoGP collection")

        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        //Evolution collectibles to fractionalize
        let chainMonstersCollection <- self.cmRewardProvider.batchWithdraw(ids: nftIds)

        FractionalVault.mintVault(
            collection: <- chainMonstersCollection, 
            collectionType: Type<@ChainmonstersRewards.Collection>(),
            bidVault: <- FlowToken.createEmptyVault(),
            bidVaultType: Type<@FlowToken.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply,
            name: name,
            description: description
        )
    }   
}