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
    shallRevert, 
    shallThrow,
    getFlowBalance
} from "flow-js-testing";
import { getVaultAdminAddress, getVaultAddress, getBobsAddress, getAlicesAddress, getCarolsAddress, getDicksAddress } from "../src/common";
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
    getReserveInfo,
    tickClock
} from "../src/fractionalVault"

import {
    setupWrappedCollectionOnAccount,
    getWNFTCollectionIds, 
    getWNFT
} from "../src/wnft"

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(500000);

describe("FractionalVault", () => {

    // Instantiate emulator and path to Cadence files
	beforeEach(async () => {
		const basePath = path.resolve(__dirname, "../");
		const port = 7001;

		await init(basePath, { port });
		return emulator.start(port, false);
	});

    // Stop emulator, so it could be restarted
	afterEach(async () => {
		return emulator.stop();
	})
    //Common Functionality

    it("should deploy FractionalVault contract", async () => {
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

    //minting a vault with multiple nfts
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

	});

    // Vaults auction functionality
    it("should be able to start and end an auction", async () => {
		// Setup
		await deployFractionalVault();
        await tickClock(0)
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        const Alice = await getAlicesAddress()
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
        
        // Checking contract variables/info 
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
        
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.resourceID).toBe(44)
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

        await updatePrice(Bob, vaultCount - 1, 0, 100, 100)

        let reserveInfo = await getReserveInfo(vaultCount - 1)
        //console.log("Reserve Info: ", reserveInfo)
        
        let bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)
        //Mint Alice the big bucks so he can buyout the vault
        await mintFlow(Alice, "1000.0")
        await shallPass(setupWrappedCollectionOnAccount(Alice));
        //Calling start will fail because the bid is to low
        await shallRevert(start(Alice, vaultCount - 1, 99))
        //Calling start will fail because the number of fractions voting for a reserve price >= 50% of supply
        await shallRevert(start(Alice, vaultCount - 1, 100))
        //update the price
        for(var i = 1; i <= 50; i++) {
            await updatePrice(Bob, vaultCount - 1, i * 100, 100, 100)
        }

        reserveInfo = await getReserveInfo(vaultCount - 1)
        //console.log("Reserve Info: ", reserveInfo)
        //Get Alice's balance
        let alicesBalance = await getFlowBalance(Alice)
        //console.log("Alice's balance: ", alicesBalance)
        //Starting the auction succeeds
        await shallPass(start(Alice, vaultCount - 1, 100))

        bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)

        alicesBalance = await getFlowBalance(Alice)
        //console.log("Alice's balance: ", alicesBalance)
        
        //Calling start again will fail because the auction has already been started
        await shallRevert(start(Alice, vaultCount - 1, 100))
        
        //Should advance time here to test that bids in the last 15 minutes increases the the auction length 
        //Carol counter bids
        const Carol = await getCarolsAddress()
        await mintFlow(Carol, "500.0")
        //Get Carol's balance
        let carolsBalance = await getFlowBalance(Carol)
        //console.log("Carol's balance: ", carolsBalance)
        await shallPass(setupWrappedCollectionOnAccount(Carol));

        bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)

        await shallPass(bid(Carol, vaultCount - 1, 200))
        
        carolsBalance = await getFlowBalance(Carol)
        //console.log("Carol's balance: ", carolsBalance)

        bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)

        //Alice bids more
        alicesBalance = await getFlowBalance(Alice)
        //console.log("Alice's balance: ", alicesBalance)
        await shallPass(bid(Alice, vaultCount - 1, 300))
        alicesBalance = await getFlowBalance(Alice)
        //console.log("Alice's balance: ", alicesBalance)
        bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)

        //Bob transfers some fractions to Dick
        const Dick = await getDicksAddress()
        await mintFlow(Dick, "10.0")
        await shallPass(setupFractionOnAccount(Dick))
        var bobscollectionids = await getFractionCollectionIds(Bob)
        for(var i = 0; i < 100; i++) {
            bobscollectionids = await getFractionCollectionIds(Bob)
            await transferFractions(Bob, Dick, bobscollectionids.slice(0, 50))
        }
        //console.log("Fractions transferred succesfully!")

        //Tick the clock (over 2 days)
        //console.log("Clicking the clock for 2 days...")
        await tickClock(172900)
        //console.log("Clock has been ticked!")

        //end the auction
        //console.log("Ending the auction")
        await end(Bob, vaultCount - 1)

        //Cash in proceeds
        bobscollectionids = await getFractionCollectionIds(Bob)
        //console.log("Bob's fractions: ", bobscollectionids)
        var dicksCollectionIds = await getFractionCollectionIds(Dick)
        //console.log("Dick's fractions: ", dicksCollectionIds)
        //console.log("Cashing in the proceeds")
        for(var i = 0; i < 100; i++) {
            bobscollectionids = await getFractionCollectionIds(Bob)
            await cash(Bob, vaultCount - 1, bobscollectionids.slice(0, 50))
        }
        //console.log("Cashed Bob's proceeds")
        for(var i = 0; i < 100; i++) {
            dicksCollectionIds = await getFractionCollectionIds(Dick)
            await cash(Dick, vaultCount - 1, dicksCollectionIds.slice(0, 50))
        }
        //console.log("Cashed Dick's proceeds")
        
	});

    /** Test redeeming an NFT */
    it("should be able to fractionalize and redeem an NFT", async () => {
		// Setup
		await deployFractionalVault();
        await tickClock(0)
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

        var bobscollectionids = await getFractionCollectionIds(Bob)

        
        //Cash in proceeds
        bobscollectionids = await getFractionCollectionIds(Bob)
        //console.log("Bob's fractions: ", bobscollectionids)
        await shallPass(setupWrappedCollectionOnAccount(Bob));
        let bobswrappedCollectionIds = await getWNFTCollectionIds(Bob)
        //console.log("Bob's wrapped NFT collection ids: ", bobswrappedCollectionIds)
        //console.log("Redeeming the underlying")
        for(var i = 0; i < 100; i++) {
            await redeem(Bob, vaultCount - 1, 100)
        }
        //console.log("Underlying has been redeemed")

        bobswrappedCollectionIds = await getWNFTCollectionIds(Bob)
        //console.log("Bob's wrapped NFT collection ids: ", bobswrappedCollectionIds)
        //console.log("Id: ", bobswrappedCollectionIds[0])
        let redeemedWnft = await getWNFT(Bob, bobswrappedCollectionIds[0])
        //console.log("WNFT: ", redeemedWnft)
        
        //unwrap the underlying NFT
	});
    

    /** ADD PRE AND POST CHECKS TO CONTRACTS */
    
    //Look at core contracts for other things I should test

})
