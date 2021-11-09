import path from "path";

import { 
    emulator, 
    init,
    mintFlow,
    getServiceAddress,
    deployContract,
    executeScript,
    getAccountAddress,
    shallPass,
    shallResolve,
    shallRevert 
} from "flow-js-testing";
import { getVaultAdminAddress, getVaultAddress, getBobsAddress, getAlicesAddress } from "../src/common";
import {
    deployFraction,
    setupFractionOnAccount,
    transferFractions,
    getCollectionBalance,
    getFractionCollectionIds,
    getCount,
    getFractionSupply,
    getFractionsByVault,
    getTotalSupply,
    getFraction

} from "../src/fraction"
import { 
    deployExampleNFT,
    setupExampleNFTOnAccount,
    mintExampleNFT,
    getExampleNFTCollectionIds,
    getCollectionLength,
    getNFT
} from "../src/exampleNFT"

import {
    deployFractionalVault,
    setupVaultOnAccount,
    mintVault,
    start,
    end,
    bid,
    cash,
    redeem,
    updatePrice,
    getVaultCount,
    getVault,
    getBidVaultBalance,
    getFractionIds,
    getUnderlyingCollectionIds,
    getUnderlyingNFT,
    getUnderlyingWNFT,
    mintVaultFractions,
    getReserveInfo
} from "../src/fractionalVault"

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(500000);

describe("FractionalVault", () => {

    // Instantiate emulator and path to Cadence files
	beforeEach(async () => {
		const basePath = path.resolve(__dirname, "../../");
		//const port = 7001;
		await init(basePath, { port: 8080 });
		//return emulator.start(port, false);
	});

    // Stop emulator, so it could be restarted
	/*afterEach(async () => {
		return emulator.stop();
	});*/

    //Common Functionality

    /*it("should deploy FractionalVault contract", async () => {
		await deployFractionalVault();
	});

    it("should setup fractionalVault on account ", async () => {
		await deployFractionalVault();
        const VaultAddress = await getVaultAddress()
        
        await shallPass(setupVaultOnAccount(VaultAddress));
	});

    it("count should be 0 after deployment", async () => {
		await deployFractionalVault();
        const VaultAddress = await getVaultAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
        let count = await getVaultCount()
        expect(count).toBe(0);
	});

    it("should mint an example nft to be used in a vault", async () => {
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
	});

    it("should be able to mint a vault and receive fractions", async () => {
		// Setup
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        let ids = await getExampleNFTCollectionIds(Bob)
        const VaultAddress = await getVaultAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob mints a vault
        await shallPass(mintVault(Bob, ids, Bob))
        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)

        for(var i = 0; i < 100; i++) {
            await shallPass(mintVaultFractions(VaultAdmin, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(VaultAdmin, vaultCount - 1))
        
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(10000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(10000)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(10000)
        //get collection ids
        const collectionids = await getFractionCollectionIds(Bob)
        for(var i = 0; i < 10000; i++) {
            expect(collectionids[i]).toBe(i)
        }
        
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.resourceID).toBe(41)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //get fraction ids
        const fractionIds = await getFractionIds(vaultCount - 1)
        //console.log("Fraction Ids:", fractionIds)
        expect(fractionIds.length).toBe(0)
        //get underlying WNFT
        const wnft = await getUnderlyingWNFT(vaultCount - 1, underlyingIds[0])
        expect(wnft.id).toBe(0)
        expect(wnft.address).toBe(Bob)
        //console.log("Bob", Bob)
        //console.log("WNFT: ", wnft)
        //get underlying NFT
        const nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        expect(nft.id).toBe(0)
        //console.log("NFT: ", nft)

	});

    //minting multiple vaults
    it("should be able to mint multiple vaults", async () => {
		// Setup
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        let ids = await getExampleNFTCollectionIds(Bob)
        const VaultAddress = await getVaultAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob mints a vault
        await shallPass(mintVault(Bob, ids, Bob))
        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)
        //Bob mints and the recipient (in this case, Bob himself) gets the fractions
        for(var i = 0; i < 100; i++) {
            await shallPass(mintVaultFractions(VaultAdmin, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(VaultAdmin, vaultCount - 1))
        
        //Get total supply
        let totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(10000)
        //get fraction supply
        let totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(10000)
        //get collection balance
        let collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(10000)
        //get collection ids
        let collectionids = await getFractionCollectionIds(Bob)
        for(var i = 0; i < 10000; i++) {
            expect(collectionids[i]).toBe(i)
        }
        
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.resourceID).toBe(41)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        let  underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //get fraction ids
        let fractionIds = await getFractionIds(vaultCount - 1)
        //console.log("Fraction Ids:", fractionIds)
        expect(fractionIds.length).toBe(0)
        //get underlying WNFT
        let wnft = await getUnderlyingWNFT(vaultCount - 1, underlyingIds[0])
        expect(wnft.id).toBe(0)
        expect(wnft.address).toBe(Bob)
        //console.log("Bob", Bob)
        //console.log("WNFT: ", wnft)
        //get underlying NFT
        let nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        expect(nft.id).toBe(0)
        //console.log("NFT: ", nft)

        await shallPass(mintExampleNFT(Bob, Bob))
        ids = await getExampleNFTCollectionIds(Bob)

        //Bob mints another vault
        await shallPass(mintVault(Bob, ids, Bob))
        vaultCount = await getVaultCount()
        expect(vaultCount).toBe(2)

        for(var i = 0; i < 100; i++) {
            await shallPass(mintVaultFractions(VaultAdmin, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(VaultAdmin, vaultCount - 1))

        //Get total supply
        totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(20000)
        //get fraction supply
        totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(10000)
        //get collection balance
        collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(20000)
        //get collection ids
        collectionids = await getFractionCollectionIds(Bob)
        for(var i = 0; i < 20000; i++) {
            expect(collectionids[i]).toBe(i)
        }

        //get the new vault
        const vault2 = await getVault(vaultCount - 1)
        expect(vault2.vaultId).toBe(1)
        expect(vault2.auctionEnd).toBe(null)
        expect(vault2.auctionLength).toBe("172800.00000000")
        expect(vault2.livePrice).toBe(null)
        expect(vault2.winning).toBe(null)
        expect(vault2.auctionState).toBe(0)
        expect(vault2.resourceID).toBe(10148)
        expect(vault2.vaultAddress).toBe('0x179b6b1cb6755e31')

        //getunderlying collection ids
        underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //get fraction ids
        fractionIds = await getFractionIds(vaultCount - 1)
        //console.log("Fraction Ids:", fractionIds)
        expect(fractionIds.length).toBe(0)
        //get underlying WNFT
        wnft = await getUnderlyingWNFT(vaultCount - 1, underlyingIds[0])
        expect(wnft.id).toBe(1)
        expect(wnft.address).toBe(Bob)
        //console.log("Bob", Bob)
        //console.log("WNFT: ", wnft)
        //get underlying NFT
        nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        expect(nft.id).toBe(1)

	});

    //minting vaults from different addresses
    it("should be able to mint multiple vaults", async () => {
		// Setup
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        let ids = await getExampleNFTCollectionIds(Bob)
        const VaultAddress = await getVaultAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob mints a vault
        await shallPass(mintVault(Bob, ids, Bob))
        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)
        //Bob mints and the recipient (in this case, Bob himself) gets the fractions
        for(var i = 0; i < 100; i++) {
            await shallPass(mintVaultFractions(VaultAdmin, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(VaultAdmin, vaultCount - 1))
        
        //Get total supply
        let totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(10000)
        //get fraction supply
        let totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(10000)
        //get collection balance
        let collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(10000)
        //get collection ids
        let collectionids = await getFractionCollectionIds(Bob)
        for(var i = 0; i < 10000; i++) {
            expect(collectionids[i]).toBe(i)
        }
        
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.resourceID).toBe(41)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        let  underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //get fraction ids
        let fractionIds = await getFractionIds(vaultCount - 1)
        //console.log("Fraction Ids:", fractionIds)
        expect(fractionIds.length).toBe(0)
        //get underlying WNFT
        let wnft = await getUnderlyingWNFT(vaultCount - 1, underlyingIds[0])
        expect(wnft.id).toBe(0)
        expect(wnft.address).toBe(Bob)
        //console.log("Bob", Bob)
        //console.log("WNFT: ", wnft)
        //get underlying NFT
        let nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        expect(nft.id).toBe(0)
        //console.log("NFT: ", nft)

        const Alice = await getAlicesAddress()
        //Mint flow to Bob
        await mintFlow(Alice, "10.0")
        await shallPass(setupExampleNFTOnAccount(Alice))
        await shallPass(mintExampleNFT(Alice, Alice))
        ids = await getExampleNFTCollectionIds(Alice) 

        //setup fraction collection
        await shallPass(setupFractionOnAccount(Alice))

        //Bob mints another vault
        await shallPass(mintVault(Alice, ids, Alice))
        vaultCount = await getVaultCount()
        expect(vaultCount).toBe(2)
        for(var i = 0; i < 100; i++) {
            await shallPass(mintVaultFractions(VaultAdmin, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(VaultAdmin, vaultCount - 1))

        //Get total supply
        totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(20000)
        //get fraction supply
        totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(10000)
        //get alicecollection balance
        let alicesCollectionBalance = await getCollectionBalance(Alice)
        expect(alicesCollectionBalance).toBe(10000)
        // get bob's balance
        let bobsCollectionBalance = await getCollectionBalance(Bob)
        expect(bobsCollectionBalance).toBe(10000)

        //get the new vault
        const vault2 = await getVault(vaultCount - 1)
        expect(vault2.vaultId).toBe(1)
        expect(vault2.auctionEnd).toBe(null)
        expect(vault2.auctionLength).toBe("172800.00000000")
        expect(vault2.livePrice).toBe(null)
        expect(vault2.winning).toBe(null)
        expect(vault2.auctionState).toBe(0)
        expect(vault2.resourceID).toBe(10155)
        expect(vault2.vaultAddress).toBe('0x179b6b1cb6755e31')

        //getunderlying collection ids
        underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //length of the underlying collection holding 1 NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //get fraction ids
        fractionIds = await getFractionIds(vaultCount - 1)
        //console.log("Fraction Ids:", fractionIds)
        expect(fractionIds.length).toBe(0)
        //get underlying WNFT
        wnft = await getUnderlyingWNFT(vaultCount - 1, underlyingIds[0])
        expect(wnft.id).toBe(1)
        expect(wnft.address).toBe(Alice)
        //console.log("Bob", Bob)
        //console.log("WNFT: ", wnft)
        //get underlying NFT
        nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        expect(nft.id).toBe(1)

        let bobscollectionids = await getFractionCollectionIds(Bob)
        //transfer some fractions
        await transferFractions(Bob, Alice, bobscollectionids.slice(0, 100))
        //get alicecollection balance
        alicesCollectionBalance = await getCollectionBalance(Alice)
        expect(alicesCollectionBalance).toBe(10100)
        // get bob's balance
        bobsCollectionBalance = await getCollectionBalance(Bob)
        expect(bobsCollectionBalance).toBe(9900)
        

	});

    //minting a vault with multiple nfts
    //THIS DOES NOT GAURANTEE NFTS OF DIFFERENT COLLECTIONS CAN BE DEPOSITED AT THE SAME TIME 
    it("should be able to mint a vault with multiple NFTs", async () => {
		// Setup
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        //mint 2 NFTs to Bob
        await shallPass(mintExampleNFT(Bob, Bob))
        await shallPass(mintExampleNFT(Bob, Bob))

        let ids = await getExampleNFTCollectionIds(Bob)
        const VaultAddress = await getVaultAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob mints a vault
        await shallPass(mintVault(Bob, ids, Bob))
        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)

        for(var i = 0; i < 100; i++) {
            await shallPass(mintVaultFractions(VaultAdmin, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(VaultAdmin, vaultCount - 1))
        
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(10000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(10000)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(10000)
        //get collection ids
        const collectionids = await getFractionCollectionIds(Bob)
        for(var i = 0; i < 10000; i++) {
            expect(collectionids[i]).toBe(i)
        }
        
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.resourceID).toBe(43)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')

        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //number of NFTS in the vault
        expect(underlyingIds.length).toBe(2)

        //get fraction ids
        const fractionIds = await getFractionIds(vaultCount - 1)
        expect(fractionIds.length).toBe(0)

        //get underlying WNFT
        const wnft = await getUnderlyingWNFT(vaultCount - 1, underlyingIds[0])
        const wnft2 = await getUnderlyingWNFT(vaultCount - 1, underlyingIds[1])
        expect(wnft.id).toBe(0)
        expect(wnft.address).toBe(Bob)
        expect(wnft2.id).toBe(1)
        expect(wnft2.address).toBe(Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        const nft2 = await getUnderlyingNFT(vaultCount - 1, underlyingIds[1])
        expect(nft.id).toBe(0)
        expect(nft2.id).toBe(1)

	});*/

    // Vaults auction functionality
    it("should be able to start an auction", async () => {
		// Setup
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        let ids = await getExampleNFTCollectionIds(Bob)
        const VaultAddress = await getVaultAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob mints a vault
        await shallPass(mintVault(Bob, ids, Bob))
        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)

        for(var i = 0; i < 100; i++) {
            await shallPass(mintVaultFractions(VaultAdmin, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(VaultAdmin, vaultCount - 1))
        
        /** Checking contract variables/info */
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(10000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(10000)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(10000)
        //get collection ids
        const collectionids = await getFractionCollectionIds(Bob)
        for(var i = 0; i < 10000; i++) {
            expect(collectionids[i]).toBe(i)
        }
        
        /**Checking scripts to query the vault */
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.resourceID).toBe(41)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //get fraction ids
        const fractionIds = await getFractionIds(vaultCount - 1)
        //console.log("Fraction Ids:", fractionIds)
        expect(fractionIds.length).toBe(0)
        //get underlying WNFT
        const wnft = await getUnderlyingWNFT(vaultCount - 1, underlyingIds[0])
        expect(wnft.id).toBe(0)
        expect(wnft.address).toBe(Bob)
        //console.log("Bob", Bob)
        //console.log("WNFT: ", wnft)
        //get underlying NFT
        const nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        expect(nft.id).toBe(0)
        //console.log("NFT: ", nft)

        //Get reserve info
        let reserveInfo = await getReserveInfo(vaultCount - 1)
        console.log("Reserve Info: ", reserveInfo)
        //Can update price
        //emulator.setLogging(true);

        let collectionIds = await getFractionCollectionIds(Bob)
        console.log("Collection Ids: ", collectionIds)

        let tx =  await updatePrice(Bob, vaultCount - 1, 100, 100)

        console.log("Tx: ", tx)
        
        console.log("Tx Data: ", tx.events[0].data)

        reserveInfo = await getReserveInfo(vaultCount - 1)
        console.log("Reserve Info: ", reserveInfo)

        //emulator.setLogging(false);
        
        //Transfer some fractions from Bob to Alice

	});

    
    /** TEST COMPTUATIONAL LIMITS FOR AUCTION FUNCTIONS */

    /** ADD PRE AND POST CHECKS TO CONTRACTS */
    
    //Look at core contracts for other things I should test




    


})
