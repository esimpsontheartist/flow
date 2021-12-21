import path from "path";

import { 
    emulator, 
    init,
    mintFlow,
    shallPass,
    shallRevert, 
    getFlowBalance
} from "flow-js-testing";
import { getVaultAdminAddress, getVaultAddress, getBobsAddress, getAlicesAddress, getCarolsAddress, getDicksAddress, getStorageUsed } from "../src/common";
import {
    setupFractionOnAccount,
    transferFractions,
    getCollectionBalance,
    getFractionCollectionIds,
    getCount,
    getFractionSupply,
    getFractionsByVault,
    getTotalSupply

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
    getUnderlyingCollectionIds,
    getUnderlyingNFT,
    mintVaultFractions,
    getReserveInfo,
    tickClock
} from "../src/fractionalVault"

import {
    setupWrappedCollectionOnAccount,
    wrap,
    getWNFTCollectionIds, 
    getWNFT
} from "../src/wnft"

import {
    deployFixedPriceSale,
    setupFixedPricesaleOnAccount,
    listForFlow,
    purchaseFlowListing,
    cancelListing,
    getListingIds,
    getListingData
} from "../src/fixedPriceSale"

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(5000000);

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
        await mintFlow(VaultAdmin, "1.0")
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        let freshStorage = await getStorageUsed(Bob)
        //console.log("Storage used: ", freshStorage)
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        const VaultAddress = await getVaultAddress()
        await mintFlow(VaultAddress, "1.0")
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await shallPass(setupWrappedCollectionOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getWNFTCollectionIds(Bob)
        
        await shallPass(
            mintVault(
                Bob, 
                wrappedIds,
                Bob,
                1000
            )
        )

        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)
        
        for(var i = 0; i < 10; i++) {
            await shallPass(mintVaultFractions(Bob, vaultCount - 1))
        }

        let storageUsed = await getStorageUsed(Bob)
        //console.log("Storage used: ", storageUsed)
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(Bob, vaultCount - 1))
        
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(1000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(1000)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(1000)
        //get collection ids
        const collectionids = await getFractionCollectionIds(Bob)
        //console.log("collectionIds: ", collectionids)
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //console.log("Bob", Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        //console.log("NFT: ", nft)

	});

    // Vaults auction functionality
    it("should be able to start and end an auction", async () => {
		// Setup
		await deployFractionalVault();
        await tickClock(0)
        const VaultAdmin = await getVaultAdminAddress()
        await mintFlow(VaultAdmin, "10.0")
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        const Alice = await getAlicesAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        const VaultAddress = await getVaultAddress()
        await mintFlow(VaultAddress, "10.0")
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await shallPass(setupWrappedCollectionOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getWNFTCollectionIds(Bob)
        
        //Bob mints a vault
        await shallPass(
            mintVault(
                Bob, 
                wrappedIds, 
                Bob,
                1000
            )
        )
        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)


        for(var i = 0; i < 10; i++) {
            await shallPass(mintVaultFractions(Bob, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(Bob, vaultCount - 1))
        
        // Checking contract variables/info 
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(1000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(1000)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(1000)
        //get collection ids
        
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //console.log("Bob", Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        //console.log("NFT: ", nft)

        await updatePrice(Bob, vaultCount - 1, 0, 100, 100)

        let reserveInfo = await getReserveInfo(vaultCount - 1)
        //console.log("Reserve Info: ", reserveInfo)
        
        let bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)
        //Mint Alice the big bucks so he can buyout the vault
        await mintFlow(Alice, "1000.0")
        await shallPass(setupExampleNFTOnAccount(Alice));
        //Calling start will fail because the bid is to low
        //console.log("Trying to start an auction")
        await shallRevert(start(Alice, vaultCount - 1, 99))
        //Calling start will fail because the number of fractions voting for a reserve price >= 50% of supply
        //console.log("Trying to start an auction")
        await shallRevert(start(Alice, vaultCount - 1, 100))
        //update the price
        for(var i = 1; i <= 5; i++) {
            await updatePrice(Bob, vaultCount - 1, i * 100, 100, 100)
        }

        reserveInfo = await getReserveInfo(vaultCount - 1)
        //console.log("Reserve Info: ", reserveInfo)
        //Get Alice's balance
        let alicesBalance = await getFlowBalance(Alice)
        
        await shallPass(setupWrappedCollectionOnAccount(Alice))
        //console.log("Starting an auction...")
        await shallPass(start(Alice, vaultCount - 1, 100))

        bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)

        alicesBalance = await getFlowBalance(Alice)
        //console.log("Alice's balance: ", alicesBalance)
        
        //Calling start again will fail because the auction has already been started
        //console.log("Trying to start an auction again reverts")
        await shallRevert(start(Alice, vaultCount - 1, 100))
        
        //Should advance time here to test that bids in the last 15 minutes increases the the auction length 
        //Carol counter bids
        const Carol = await getCarolsAddress()
        await mintFlow(Carol, "500.0")
        //Get Carol's balance
        let carolsBalance = await getFlowBalance(Carol)
        //console.log("Carol's balance: ", carolsBalance)
        await shallPass(setupExampleNFTOnAccount(Carol));

        bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)

        await shallPass(setupWrappedCollectionOnAccount(Carol))

        //console.log("Carol Bids")
        await shallPass(bid(Carol, vaultCount - 1, 200))
            
        carolsBalance = await getFlowBalance(Carol)
        //console.log("Carol's balance: ", carolsBalance)

        bidVaultBalance = await getBidVaultBalance(vaultCount - 1)
        //console.log("Bid vault balance is: ", bidVaultBalance)

        //Alice bids more
        alicesBalance = await getFlowBalance(Alice)

        //console.log("Alice bids some more")
        await shallPass(bid(Alice, vaultCount - 1, 300))
        alicesBalance = await getFlowBalance(Alice)

        bidVaultBalance = await getBidVaultBalance(vaultCount - 1)

        //Bob transfers some fractions to Dick
        
        //console.log("Fractions transferred succesfully!")

        //Tick the clock (over 2 days)
        //console.log("Clicking the clock for 2 days...")
        await tickClock(172900)
        //console.log("Clock has been ticked!")

        //end the auction
        //console.log("Ending the auction")
        await end(Bob, vaultCount - 1)

        //Cash in proceeds
        var bobscollectionids = await getFractionCollectionIds(Bob)
        console.log("Bob's fractions: ", bobscollectionids)
        //var dicksCollectionIds = await getFractionCollectionIds(Dick)
        //console.log("Dick's fractions: ", dicksCollectionIds)
        //console.log("Cashing in the proceeds")
        await cash(Bob, vaultCount - 1)
        console.log("Cashed Bob's proceeds")
        bobscollectionids = await getFractionCollectionIds(Bob)
        console.log("Bob's fractions: ", bobscollectionids)
        
	});

    
    it("should be able to fractionalize and redeem an NFT", async () => {
		// Setup
		await deployFractionalVault();
        await tickClock(0)
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        await mintFlow(VaultAdmin, "10.0")
        const Bob = await getBobsAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        let ids = await getExampleNFTCollectionIds(Bob)
        const VaultAddress = await getVaultAddress()
        await mintFlow(VaultAddress, "10.0")
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await shallPass(setupWrappedCollectionOnAccount(Bob))
        //Bob wraps his example NFT
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getWNFTCollectionIds(Bob)
        //Bob mints a vault
        await shallPass(
            mintVault(
                Bob, 
                wrappedIds, 
                Bob,
                1000
            )
        )

        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)

        for(var i = 0; i < 10; i++) {
            await shallPass(mintVaultFractions(Bob, vaultCount - 1))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(Bob, vaultCount - 1))
        
        //Checking contract variables/info 
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(1000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(1000)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(1000)
        //get collection ids
        
        // Checking scripts to query the vault 
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //console.log("Bob", Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        //console.log("NFT: ", nft)

        var bobscollectionids = await getFractionCollectionIds(Bob)

        
        //Cash in proceeds
        bobscollectionids = await getFractionCollectionIds(Bob)
        //console.log("Bob's fractions: ", bobscollectionids)
        await shallPass(setupWrappedCollectionOnAccount(Bob));
        let bobswrappedCollectionIds = await getWNFTCollectionIds(Bob)
        //console.log("Bob's wrapped NFT collection ids: ", bobswrappedCollectionIds)
        //console.log("Redeeming the underlying")
        await redeem(Bob, vaultCount - 1, 100)
        //console.log("Underlying has been redeemed")

        bobswrappedCollectionIds = await getWNFTCollectionIds(Bob)
        //console.log("Bob's wrapped NFT collection ids: ", bobswrappedCollectionIds)
        //console.log("Id: ", bobswrappedCollectionIds[0])
        let redeemedWnft = await getWNFT(Bob, bobswrappedCollectionIds[0])
        //console.log("WNFT: ", redeemedWnft)
        
	});

    it("should be able to deploy the fixed price sale", async() => {
        await deployFixedPriceSale()
        const Bob = await getBobsAddress()
        let tx = await setupFixedPricesaleOnAccount(Bob)
        //console.log(tx)
    })

    it("should be able to list and sell some fractions", async () => {
		// Setup
		await deployFixedPriceSale()
        await tickClock(0)
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        await mintFlow(VaultAdmin, "10.0")
        const Bob = await getBobsAddress()
        const Alice = await getAlicesAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        const VaultAddress = await getVaultAddress()
        await mintFlow(VaultAddress, "10.0")
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await shallPass(setupWrappedCollectionOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getWNFTCollectionIds(Bob)
        
        //Bob mints a vault
        await shallPass(
            mintVault(
                Bob, 
                wrappedIds, 
                Bob,
                1000
            )
        )
        let vaultCount = await getVaultCount()
        expect(vaultCount).toBe(1)


        for(var i = 0; i < 9; i++) {
            await shallPass(mintVaultFractions(Bob, vaultCount - 1))
        }
        
        // Checking contract variables/info 
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(900)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(vaultCount - 1)
        expect(totalFractionSupply).toBe(900)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(900)
        //get collection ids
        
        //get the vault
        const vault = await getVault(vaultCount - 1)
        expect(vault.vaultId).toBe(0)
        expect(vault.auctionEnd).toBe(null)
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe(null)
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(0)
        expect(vault.vaultAddress).toBe('0x179b6b1cb6755e31')
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(vaultCount - 1)
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //console.log("Bob", Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(vaultCount - 1, underlyingIds[0])
        //console.log("NFT: ", nft)

       // Setup fixed price sale on Bob's account
       await shallPass(setupFixedPricesaleOnAccount(Bob))
       //console.log("Successfully set up fixed price sale on Bob's account")
       //Bob lists 50 fractions
       await shallPass(listForFlow(Bob, 0, 50, 0.1))
       
       let listingIds = await getListingIds(Bob)
       //console.log("ListingIds: ", listingIds)

       await mintFlow(Alice, "1000.0")
       await shallPass(setupFractionOnAccount(Alice))
       
       let alicesFractions = await getFractionCollectionIds(Alice)
       //console.log("Alice's fractions: ", alicesFractions)
       //Alice buys the 50 fractions from Bob
       await purchaseFlowListing(Alice, listingIds[0], Bob, 5)

       alicesFractions = await getFractionCollectionIds(Alice)
       //console.log("Alice's fractions: ", alicesFractions)

       await shallPass(listForFlow(Bob, 0, 50, 0.2))
       
       
       listingIds = await getListingIds(Bob)
       //console.log("ListingIds: ", listingIds)

       //Bob cancels the listing
       await shallPass(cancelListing(Bob, listingIds[0]))

       await shallPass(listForFlow(Bob, 0, 50, 0.2))
       
       listingIds = await getListingIds(Bob)
       //console.log("ListingIds: ", listingIds)

       await purchaseFlowListing(Alice, listingIds[0], Bob, 10)

       alicesFractions = await getFractionCollectionIds(Alice)
       //console.log("Alice's fractions: ", alicesFractions)

        
	});
    

})
