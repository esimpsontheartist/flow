import AllDay from "../../../contracts/third-party/AllDay.cdc"
import FUSD from "../../../contracts/core/FUSD.cdc"
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
    //Collection to pull the topshot moments from
    let allDayProvider: &AllDay.Collection
    //Curator capability to mint or list fractions
    let curator: Capability<&Fraction.Collection>

    prepare(account: AuthAccount) {

        self.allDayProvider = account.borrow<&AllDay.Collection>(from: AllDay.CollectionStoragePath) 
        ?? panic("could not borrow a reference to the topshot collection")

        self.curator = account.getCapability<&Fraction.Collection>(Fraction.CollectionPrivatePath)
    }

    pre {
        self.curator.check() == true : "mint_vault:capability not linked"
    }

    execute {
        //Topshot moments to fractionalize
        let allDayCollection <- AllDay.createEmptyCollection()

        for id in nftIds {
            allDayCollection.deposit(token: <- self.allDayProvider.withdraw(withdrawID: id))
        }
        
        FractionalVault.mintVault(
            collection: <- allDayCollection, 
            collectionType: Type<@AllDay.Collection>(),
            bidVault: <- FUSD.createEmptyVault(),
            bidVaultType: Type<@FUSD.Vault>(),
            curator: self.curator, 
            maxSupply: maxSupply,
            name: name,
            description: description
        )
    }   
}