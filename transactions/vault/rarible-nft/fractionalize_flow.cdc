import RaribleNFT from "../../../contracts/third-party/RaribleNFT.cdc"
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
    //Collection to pull the rarible nfts from
    let raribleProvider: &RaribleNFT.Collection
    //Curator capability to mint or list fractions
    let curator: Capability<&Fraction.Collection>

    prepare(account: AuthAccount) {

        self.raribleProvider = account.borrow<&RaribleNFT.Collection>(from: RaribleNFT.collectionStoragePath) 
        ?? panic("could not borrow a reference to the rarible collection")

        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        //rarible nfts to fractionalize
        let raribleCollection <- RaribleNFT.createEmptyCollection() as! @RaribleNFT.Collection

        //Filling the metadata array
        for id in nftIds {
            raribleCollection.deposit(token: <- self.raribleProvider.withdraw(withdrawID: id))
        }

        FractionalVault.mintVault(
            collection: <- raribleCollection, 
            collectionType: Type<@RaribleNFT.Collection>(),
            bidVault: <- FlowToken.createEmptyVault(),
            bidVaultType: Type<@FlowToken.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply
        )
    }   
}