import path from "path";

import { 
    emulator, 
    init,
    mintFlow,
    shallPass,
    shallRevert, 
    getFlowBalance
} from "flow-js-testing";

import { 
    getVaultAdminAddress, 
    getBobsAddress, 
    getAlicesAddress, 
    getCarolsAddress,
    getDicksAddress,
    getStorageUsed 
} from "../src/common";

import {
    setupCoreVaultOnAccount,
    mintCoreVault,
    getCoreVaultCount,
    getCoreVaultIds,
    getCoreVault,
    getCoreVaultUnderlyingIds
} from "../src/coreVault";

import {
    setupFractionOnAccount,
    transferFractions,
    burnFractions, 
    getCollectionBalance,
    getFractionCollectionIds,
    getCount,
    getFractionSupply,
    getFractionsByVault,
    getBurnerCollectionNum,
    getBurnerAmountAt,
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
    updateUserPrice,
    manageVaultFee,
    overrideBidVaultPath,
    badOverrideBidVaultPath,
    withdrawVault,
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
    deployBasket,
    setupBasketOnAccount,
    wrap,
    getBasketCollectionIds, 
    getWNFT
} from "../src/basket"

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

    /*
     * Deploys all the contracts related to FractionalVault module
     */
    it("should deploy FractionalVault contract", async () => {
		await deployFractionalVault();
	});

    it("should setup fractionalVault on account ", async () => {
		await deployFractionalVault();
        const VaultAddress = await getVaultAdminAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
	});

    it("count should be 0 after deployment", async () => {
		await deployFractionalVault();
        const VaultAddress = await getVaultAdminAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
        let count = await getCoreVaultCount()
        expect(count).toBe(0);
	});

    it("should be able to withdraw coreVault if no fractions are minted", async () => {
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
        await mintFlow(VaultAdmin, "1.0")
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //let freshStorage = await getStorageUsed(Bob)
        //console.log("Storage used: ", freshStorage)
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        await shallPass(setupCoreVaultOnAccount(Bob))
        await shallPass(setupVaultOnAccount(Bob));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await deployBasket()
        await shallPass(setupBasketOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getBasketCollectionIds(Bob)
        
        await shallPass(
            mintCoreVault(Bob, wrappedIds)
        )

        let vaultCount = await getCoreVaultCount()
        expect(vaultCount).toBe(1)

        let bobsVaultIds = await getCoreVaultIds(Bob)
        //console.log("Bob's core vault ids: ", bobsVaultIds)

        //let bobsVault = await getCoreVault(Bob, bobsVaultIds[0])
        //console.log("Bob's vault: ", bobsVault)

        await shallPass(
            mintVault(
                Bob, 
                bobsVaultIds[0],
                1000
            )
        )

        await shallPass(withdrawVault(Bob,  bobsVaultIds[0]))
	});

    it("can't withdraw coreVault if fractions have been minted", async () => {
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
        await mintFlow(VaultAdmin, "1.0")
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //let freshStorage = await getStorageUsed(Bob)
        //console.log("Storage used: ", freshStorage)
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        await shallPass(setupCoreVaultOnAccount(Bob))
        await shallPass(setupVaultOnAccount(Bob));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await deployBasket()
        await shallPass(setupBasketOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getBasketCollectionIds(Bob)
        
        await shallPass(
            mintCoreVault(Bob, wrappedIds)
        )

        let vaultCount = await getCoreVaultCount()
        expect(vaultCount).toBe(1)

        let bobsVaultIds = await getCoreVaultIds(Bob)
        //console.log("Bob's core vault ids: ", bobsVaultIds)

        //let bobsVault = await getCoreVault(Bob, bobsVaultIds[0])
        //console.log("Bob's vault: ", bobsVault)

        await shallPass(
            mintVault(
                Bob, 
                bobsVaultIds[0],
                1000
            )
        )

        await shallPass(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 100))
        

        await shallRevert(withdrawVault(Bob,  bobsVaultIds[0]))
	});

    it("should be able to mint a vault and receive fractions", async () => {
		// Setup
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
        await mintFlow(VaultAdmin, "1.0")
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //let freshStorage = await getStorageUsed(Bob)
        //console.log("Storage used: ", freshStorage)
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        await shallPass(setupCoreVaultOnAccount(Bob))
        await shallPass(setupVaultOnAccount(Bob));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await deployBasket()
        await shallPass(setupBasketOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getBasketCollectionIds(Bob)
        
        await shallPass(
            mintCoreVault(Bob, wrappedIds)
        )

        let vaultCount = await getCoreVaultCount()
        expect(vaultCount).toBe(1)

        let bobsVaultIds = await getCoreVaultIds(Bob)
        //console.log("Bob's core vault ids: ", bobsVaultIds)

        //let bobsVault = await getCoreVault(Bob, bobsVaultIds[0])
        //console.log("Bob's vault: ", bobsVault)

        await shallPass(
            mintVault(
                Bob, 
                bobsVaultIds[0],
                1000
            )
        )
        
        for(var i = 0; i < 10; i++) {
            await shallPass(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 100))
        }

        //let storageUsed = await getStorageUsed(Bob)
        //console.log("Storage used: ", storageUsed)

        //Get total supply
        let totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(1000)
        //console.log("TotalSupply: ", totalSupply)
        //Tying to mint after 1k fractions will revert
        const totalFractionSupply = await getFractionSupply(bobsVaultIds[0])
        expect(totalFractionSupply).toBe(1000)
        await shallRevert(mintVaultFractions(Bob, bobsVaultIds[0], 1))
        
        
        //get fraction supply
        
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(1000)
        //get collection ids
        const collectionids = await getFractionCollectionIds(Bob)
        //console.log("collectionIds: ", collectionids)
        //get the vault
        const vault = await getVault(Bob, bobsVaultIds[0])
        //console.log("Vault: ", vault)
        expect(vault.vaultId).toBe(bobsVaultIds[0])
        expect(vault.auctionEnd).toBe("0.00000000")
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe("0.00000000")
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(1)
        expect(vault.address).toBe(Bob)
        
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(Bob, bobsVaultIds[0])
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //console.log("Bob", Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(Bob, bobsVaultIds[0], underlyingIds[0])
        expect(nft.id).toBe(underlyingIds[0])

	});

    // Vault auction functionality (with fees off)
    it("should be able to start and end an auction (with fees off)", async () => {
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
        await shallPass(setupCoreVaultOnAccount(Bob))
        await shallPass(setupVaultOnAccount(Bob));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await deployBasket()
        await shallPass(setupBasketOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getBasketCollectionIds(Bob)
        
        //Bob mints a CoreVault
        await shallPass(
            mintCoreVault(Bob, wrappedIds)
        )

        let vaultCount = await getCoreVaultCount()
        expect(vaultCount).toBe(1)

        let bobsVaultIds = await getCoreVaultIds(Bob)
        //console.log("Bob's core vault ids: ", bobsVaultIds)

        //let bobsVault = await getCoreVault(Bob, bobsVaultIds[0])
        //console.log("Bob's vault: ", bobsVault)
        //Bob mints a vault
        await shallPass(
            mintVault(
                Bob, 
                bobsVaultIds[0],
                1000
            )
        )
        
        for(var i = 0; i < 9; i++) {
            await shallPass(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 100))
        }
        
        const Dick = await getDicksAddress()
        await mintFlow(Dick, "5.0")
        await shallPass(setupFractionOnAccount(Bob))
        //Dick receives 100 fractions at mint
        await shallPass(setupFractionOnAccount(Dick))
        await shallPass(mintVaultFractions(Bob, Dick, bobsVaultIds[0], 100))
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 1))
        
        // Checking contract variables/info 
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(1000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(bobsVaultIds[0])
        expect(totalFractionSupply).toBe(1000)

        //get collection ids
        
        //get the vault
        const vault = await getVault(Bob, bobsVaultIds[0])
        expect(vault.vaultId).toBe(bobsVaultIds[0])
        expect(vault.auctionEnd).toBe("0.00000000")
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe("0.00000000")
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(1)
        expect(vault.address).toBe(Bob)
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(Bob, bobsVaultIds[0])


        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //console.log("Bob", Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(Bob, bobsVaultIds[0], underlyingIds[0])
        expect(nft.id).toBe(underlyingIds[0])

        //Dick sets a price
        await shallPass(updateUserPrice(Dick, Bob, bobsVaultIds[0], 100))

        let reserveInfo = await getReserveInfo(bobsVaultIds[0])
        expect(reserveInfo.voting).toBe(100)
        expect(reserveInfo.reserve).toBe("100.00000000")
        
        //Mint Alice the big bucks so she can buyout the vault
        await mintFlow(Alice, "1000.0")
        await shallPass(setupBasketOnAccount(Alice))
        //Calling start will fail because the number of fractions voting for a reserve price >= 50% of supply
        //console.log("Trying to start an auction")
        await shallRevert(start(Alice, Bob, bobsVaultIds[0], 100))
        //update the price
        await shallPass(updateUserPrice(Bob, Bob, bobsVaultIds[0], 100))
        
        //Calling start will fail because the bid is to low
        await shallRevert(start(Alice, Bob, bobsVaultIds[0], 99))

        reserveInfo = await getReserveInfo(bobsVaultIds[0])
        expect(reserveInfo.voting).toBe(1000)
        expect(reserveInfo.reserve).toBe("100.00000000")
        //Get Alice's balance
        //console.log("Starting an auction...")
        await shallPass(start(Alice, Bob, bobsVaultIds[0], 100))

        let bidVaultBalance = await getBidVaultBalance(Bob, bobsVaultIds[0])
        expect(bidVaultBalance).toBe("100.00000000")

        let alicesBalance = await getFlowBalance(Alice)
        expect(alicesBalance).toBe("900.00100000")
        
        //Calling start again will fail because the auction has already been started
        //console.log("Trying to start an auction again reverts")
        await shallRevert(start(Alice, Bob, bobsVaultIds[0], 100))
        
        //Should advance time here to test that bids in the last 15 minutes increases the the auction length 
        //Carol counter bids
        const Carol = await getCarolsAddress()
        await mintFlow(Carol, "500.0")
        await shallPass(setupExampleNFTOnAccount(Carol));
        await shallPass(setupBasketOnAccount(Carol))

        //console.log("Carol Bids")
        await shallPass(bid(Carol, Bob, bobsVaultIds[0], 200))
            
        let carolsBalance = await getFlowBalance(Carol)
        expect(carolsBalance).toBe("300.00100000")

        bidVaultBalance = await getBidVaultBalance(Bob, bobsVaultIds[0])
        expect(bidVaultBalance).toBe("200.00000000")

        //Alice bids more
        alicesBalance = await getFlowBalance(Alice)

        //console.log("Alice bids some more")
        await shallPass(bid(Alice, Bob, bobsVaultIds[0], 300))
        alicesBalance = await getFlowBalance(Alice)

        bidVaultBalance = await getBidVaultBalance(Bob, bobsVaultIds[0])
        expect(bidVaultBalance).toBe("300.00000000")
        //Tick the clock (over 2 days)
        //console.log("Clicking the clock for 2 days...")
        await shallPass(tickClock(172900))
        //console.log("Clock has been ticked!")

        //end the auction
        //Showing that anybody can send the transaction to end the auction
        //But that the underlying goes to the highest bidder
        await shallPass(end(Carol, Bob, bobsVaultIds[0]))

        // Bob cashes in
        await shallPass(cash(Bob, Bob, bobsVaultIds[0]))
        let bobsBalance = await getFlowBalance(Bob)
        expect(bobsBalance).toBe("280.00100000")
        let bobsFractionBalance = await getCollectionBalance(Bob)
        expect(bobsFractionBalance).toBe(0)
        let burnerAmount = await getBurnerCollectionNum(VaultAdmin)
        expect(burnerAmount).toBe(1)
        let burnerAmountAt = await getBurnerAmountAt(VaultAdmin, 0)
        expect(burnerAmountAt).toBe(900)

        // Dick cashes in
        await shallPass(cash(Dick, Bob, bobsVaultIds[0]))
        let dicksBalance = await getFlowBalance(Dick)
        expect(dicksBalance).toBe("35.00100000")
        let dicksFractionBalance = await getCollectionBalance(Dick)
        expect(dicksFractionBalance).toBe(0)
        burnerAmount = await getBurnerCollectionNum(VaultAdmin)
        expect(burnerAmount).toBe(2)
        burnerAmountAt = await getBurnerAmountAt(VaultAdmin, 1)
        expect(burnerAmountAt).toBe(100)
        
	});

    // Vault auction functionality (with fees on)
    it("should be able to start and end an auction (with fees on)", async () => {
		// Setup
		await deployFractionalVault();
        await tickClock(0)
        const VaultAdmin = await getVaultAdminAddress()
        await mintFlow(VaultAdmin, "10.0")
		await deployExampleNFT(VaultAdmin);
        await shallPass(manageVaultFee(VaultAdmin, "0.025"))
        const Bob = await getBobsAddress()
        const Alice = await getAlicesAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        await shallPass(setupCoreVaultOnAccount(Bob))
        await shallPass(setupVaultOnAccount(Bob));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await deployBasket()
        await shallPass(setupBasketOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getBasketCollectionIds(Bob)
        
        //Bob mints a CoreVault
        await shallPass(
            mintCoreVault(Bob, wrappedIds)
        )

        let vaultCount = await getCoreVaultCount()
        expect(vaultCount).toBe(1)

        let bobsVaultIds = await getCoreVaultIds(Bob)
        //console.log("Bob's core vault ids: ", bobsVaultIds)

        //let bobsVault = await getCoreVault(Bob, bobsVaultIds[0])
        //console.log("Bob's vault: ", bobsVault)
        //Bob mints a vault
        await shallPass(
            mintVault(
                Bob, 
                bobsVaultIds[0],
                1000
            )
        )
        
        for(var i = 0; i < 9; i++) {
            await shallPass(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 100))
        }
        
        const Dick = await getDicksAddress()
        await mintFlow(Dick, "5.0")
        await shallPass(setupFractionOnAccount(Bob))
        //Dick receives 100 fractions at mint
        await shallPass(setupFractionOnAccount(Dick))
        await shallPass(mintVaultFractions(Bob, Dick, bobsVaultIds[0], 100))
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 1))
        
        // Checking contract variables/info 
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(1000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(bobsVaultIds[0])
        expect(totalFractionSupply).toBe(1000)

        //get collection ids
        
        //get the vault
        const vault = await getVault(Bob, bobsVaultIds[0])
        expect(vault.vaultId).toBe(bobsVaultIds[0])
        expect(vault.auctionEnd).toBe("0.00000000")
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe("0.00000000")
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(1)
        expect(vault.address).toBe(Bob)
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(Bob, bobsVaultIds[0])


        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //console.log("Bob", Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(Bob, bobsVaultIds[0], underlyingIds[0])
        expect(nft.id).toBe(underlyingIds[0])

        //Dick sets a price
        await shallPass(updateUserPrice(Dick, Bob, bobsVaultIds[0], 100))

        let reserveInfo = await getReserveInfo(bobsVaultIds[0])
        expect(reserveInfo.voting).toBe(100)
        expect(reserveInfo.reserve).toBe("100.00000000")
        
        //Mint Alice the big bucks so she can buyout the vault
        await mintFlow(Alice, "1000.0")
        await shallPass(setupBasketOnAccount(Alice))
        //Calling start will fail because the number of fractions voting for a reserve price >= 50% of supply
        //console.log("Trying to start an auction")
        await shallRevert(start(Alice, Bob, bobsVaultIds[0], 100))
        //update the price
        await shallPass(updateUserPrice(Bob, Bob, bobsVaultIds[0], 100))
        
        //Calling start will fail because the bid is to low
        await shallRevert(start(Alice, Bob, bobsVaultIds[0], 99))

        reserveInfo = await getReserveInfo(bobsVaultIds[0])
        expect(reserveInfo.voting).toBe(1000)
        expect(reserveInfo.reserve).toBe("100.00000000")
        //Get Alice's balance
        //console.log("Starting an auction...")
        await shallPass(start(Alice, Bob, bobsVaultIds[0], 100))

        let bidVaultBalance = await getBidVaultBalance(Bob, bobsVaultIds[0])
        expect(bidVaultBalance).toBe("100.00000000")

        let alicesBalance = await getFlowBalance(Alice)
        expect(alicesBalance).toBe("900.00100000")
        
        //Calling start again will fail because the auction has already been started
        //console.log("Trying to start an auction again reverts")
        await shallRevert(start(Alice, Bob, bobsVaultIds[0], 100))
        
        //Should advance time here to test that bids in the last 15 minutes increases the the auction length 
        //Carol counter bids
        const Carol = await getCarolsAddress()
        await mintFlow(Carol, "500.0")
        await shallPass(setupExampleNFTOnAccount(Carol));
        await shallPass(setupBasketOnAccount(Carol))

        //console.log("Carol Bids")
        await shallPass(bid(Carol, Bob, bobsVaultIds[0], 200))
            
        let carolsBalance = await getFlowBalance(Carol)
        expect(carolsBalance).toBe("300.00100000")

        bidVaultBalance = await getBidVaultBalance(Bob, bobsVaultIds[0])
        expect(bidVaultBalance).toBe("200.00000000")

        //Alice bids more
        alicesBalance = await getFlowBalance(Alice)

        //console.log("Alice bids some more")
        await shallPass(bid(Alice, Bob, bobsVaultIds[0], 300))
        alicesBalance = await getFlowBalance(Alice)

        bidVaultBalance = await getBidVaultBalance(Bob, bobsVaultIds[0])
        expect(bidVaultBalance).toBe("300.00000000")
        //Tick the clock (over 2 days)
        //console.log("Clicking the clock for 2 days...")
        await shallPass(tickClock(172900))
        //console.log("Clock has been ticked!")

        //end the auction
        //Showing that anybody can send the transaction to end the auction
        //But that the underlying goes to the highest bidder
        let vaultAdminBalance =  await getFlowBalance(VaultAdmin)
        expect(vaultAdminBalance).toBe("60.00100000")

        //we intentionally ovveride the path to show what would happen if the path was wrong
        //this mocks a malicios actor fromtrying to create a vault, mint fractions, and then
        //have their vault not "end()" by providing a wrong path when protocol fees are turned on
        await shallPass(badOverrideBidVaultPath(VaultAdmin, Bob, bobsVaultIds[0]))
        await shallRevert(end(Carol, Bob, bobsVaultIds[0]))
        //This shows how the contract owner "Fractional", is able to override the path used 
        //for the protocol to receive fees in case the original path does not match the token
        //that was used for bidding
        await shallPass(overrideBidVaultPath(VaultAdmin, Bob, bobsVaultIds[0]))
        await shallPass(end(Carol, Bob, bobsVaultIds[0]))

        vaultAdminBalance =  await getFlowBalance(VaultAdmin)
        expect(vaultAdminBalance).toBe("67.50100000")

        // Bob cashes in
        await shallPass(cash(Bob, Bob, bobsVaultIds[0]))
        let bobsBalance = await getFlowBalance(Bob)
        expect(bobsBalance).toBe("273.25100000")
        let bobsFractionBalance = await getCollectionBalance(Bob)
        expect(bobsFractionBalance).toBe(0)
        let burnerAmount = await getBurnerCollectionNum(VaultAdmin)
        expect(burnerAmount).toBe(1)
        let burnerAmountAt = await getBurnerAmountAt(VaultAdmin, 0)
        expect(burnerAmountAt).toBe(900)

        // Dick cashes in
        await shallPass(cash(Dick, Bob, bobsVaultIds[0]))
        let dicksBalance = await getFlowBalance(Dick)
        expect(dicksBalance).toBe("34.25100000")
        let dicksFractionBalance = await getCollectionBalance(Dick)
        expect(dicksFractionBalance).toBe(0)
        burnerAmount = await getBurnerCollectionNum(VaultAdmin)
        expect(burnerAmount).toBe(2)
        burnerAmountAt = await getBurnerAmountAt(VaultAdmin, 1)
        expect(burnerAmountAt).toBe(100)
        
        //The burner has 1000 fractions, so we burn them
        for(var i = 0; i < 9; i++) {
            await shallPass(burnFractions(Bob, VaultAdmin, 100))
        }
        burnerAmount = await getBurnerCollectionNum(VaultAdmin)
        expect(burnerAmount).toBe(0)
        
	});

    
    it("should be able to fractionalize and redeem an NFT", async () => {
		// Setup
		await deployFractionalVault();
        await shallPass(tickClock(0))
        const VaultAdmin = await getVaultAdminAddress()
        await mintFlow(VaultAdmin, "10.0")
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        //Mint flow to Bob
        await mintFlow(Bob, "10.0")
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        
        await shallPass(setupCoreVaultOnAccount(Bob))
        await shallPass(setupVaultOnAccount(Bob));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await deployBasket()
        await shallPass(setupBasketOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getBasketCollectionIds(Bob)
        //Bob mints a vault
        //Bob mints a CoreVault
        await shallPass(
            mintCoreVault(Bob, wrappedIds)
        )

        let vaultCount = await getCoreVaultCount()
        expect(vaultCount).toBe(1)

        let bobsVaultIds = await getCoreVaultIds(Bob)
        
        await shallPass(
            mintVault(
                Bob, 
                bobsVaultIds[0],
                1000
            )
        )
        
        for(var i = 0; i < 10; i++) {
            await shallPass(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 100))
        }
        //Tying to mint after 10k fractions will revert
        await shallRevert(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 100))
        
        //Checking contract variables/info 
        //Get total supply`
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(1000)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(bobsVaultIds[0])
        expect(totalFractionSupply).toBe(1000)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(1000)
        //get collection ids
        
        // Checking scripts to query the vault 
        //get the vault
        const vault = await getVault(Bob, bobsVaultIds[0])
        expect(vault.vaultId).toBe(bobsVaultIds[0])
        expect(vault.auctionEnd).toBe("0.00000000")
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe("0.00000000")
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(1)
        expect(vault.address).toBe(Bob)

        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(Bob, bobsVaultIds[0])
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //console.log("Underlying NFT ids: ", underlyingIds)
        //console.log("Bob", Bob)
        //get underlying NFT
        const nft = await getUnderlyingNFT(Bob, bobsVaultIds[0], underlyingIds[0])
        expect(nft.id).toBe(underlyingIds[0])
        
        let bobsBasketIds = await getBasketCollectionIds(Bob)
        expect(bobsBasketIds.length).toBe(0)
        let bobsFractionBalance = await getCollectionBalance(Bob)
        expect(bobsFractionBalance).toBe(1000)
        //console.log("Bob's wrapped NFT collection ids: ", bobswrappedCollectionIds)
        //console.log("Redeeming the underlying")
        await redeem(Bob, Bob, bobsVaultIds[0])
        //console.log("Underlying has been redeemed")

        bobsBasketIds = await getBasketCollectionIds(Bob)
        expect(bobsBasketIds.length).toBe(1)
        bobsFractionBalance = await getCollectionBalance(Bob)
        expect(bobsFractionBalance).toBe(0)
        let burnerAmount = await getBurnerCollectionNum(VaultAdmin)
        expect(burnerAmount).toBe(1)
        let burnerAmountAt = await getBurnerAmountAt(VaultAdmin, 0)
        expect(burnerAmountAt).toBe(1000)
        
	});

    it("should be able to deploy the fixed price sale", async() => {
        await deployFractionalVault();
        await deployFixedPriceSale()
        const Bob = await getBobsAddress()
        await shallPass(setupFixedPricesaleOnAccount(Bob))
    })

    it("should be able to list and sell some fractions", async () => {
		// Setup
        await deployFractionalVault();
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
        await shallPass(setupCoreVaultOnAccount(Bob))
        await shallPass(setupVaultOnAccount(Bob));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob sets up a wrapped collection
        await deployBasket()
        await shallPass(setupBasketOnAccount(Bob))
        //Bob wraps his example NFT
        let ids = await getExampleNFTCollectionIds(Bob)
        await shallPass(wrap(Bob, ids))
        //Bob mints a vault

        let wrappedIds = await getBasketCollectionIds(Bob)
        
        //Bob mints a CoreVault
        await shallPass(
            mintCoreVault(Bob, wrappedIds)
        )

        let vaultCount = await getCoreVaultCount()
        expect(vaultCount).toBe(1)

        let bobsVaultIds = await getCoreVaultIds(Bob)

        //Bob mints a vault
        await shallPass(
            mintVault(
                Bob, 
                bobsVaultIds[0],
                1000
            )
        )


        for(var i = 0; i < 9; i++) {
            await shallPass(mintVaultFractions(Bob, Bob, bobsVaultIds[0], 100))
        }
        
        // Checking contract variables/info 
        //Get total supply
        const totalSupply = await getTotalSupply()
        expect(totalSupply).toBe(900)
        //get fraction supply
        const totalFractionSupply = await getFractionSupply(bobsVaultIds[0])
        expect(totalFractionSupply).toBe(900)
        //get collection balance
        const collectionBalance = await getCollectionBalance(Bob)
        expect(collectionBalance).toBe(900)
        //get collection ids
        
        //get the vault
        const vault = await getVault(Bob, bobsVaultIds[0])
        expect(vault.vaultId).toBe(bobsVaultIds[0])
        expect(vault.auctionEnd).toBe("0.00000000")
        expect(vault.auctionLength).toBe("172800.00000000")
        expect(vault.livePrice).toBe("0.00000000")
        expect(vault.winning).toBe(null)
        expect(vault.auctionState).toBe(1)
        expect(vault.address).toBe(Bob)
        //console.log("Vault: ", vault)
        //getunderlying collection ids
        const underlyingIds = await getUnderlyingCollectionIds(Bob, bobsVaultIds[0])
        //resource id that is assigned to the NFT
        expect(underlyingIds.length).toBe(1)
        //get underlying NFT
        const nft = await getUnderlyingNFT(Bob, bobsVaultIds[0], underlyingIds[0])
        expect(nft.id).toBe(underlyingIds[0])
        //console.log("NFT: ", nft)

       // Setup fixed price sale on Bob's account
       await shallPass(setupFixedPricesaleOnAccount(Bob))
       //console.log("Successfully set up fixed price sale on Bob's account")
       //Bob lists 50 fractions
       await shallPass(listForFlow(Bob, bobsVaultIds[0], 50, 0.1))
       
       let listingIds = await getListingIds(Bob)
       expect(listingIds[0]).toBe(0)

       await mintFlow(Alice, "100.0")
       await shallPass(setupFractionOnAccount(Alice))
       
       let alicesFractions = await getFractionCollectionIds(Alice)
       expect(alicesFractions.length).toBe(0)

       //Alice buys the 50 fractions from Bob
       await purchaseFlowListing(Alice, listingIds[0], Bob, 5)

       alicesFractions = await getFractionCollectionIds(Alice)
       expect(alicesFractions.length).toBe(50)
       //console.log("Alice's fractions: ", alicesFractions)

       await shallPass(listForFlow(Bob, bobsVaultIds[0], 50, 0.2))
       
       listingIds = await getListingIds(Bob)
       expect(listingIds[0]).toBe(1)

       //Bob cancels the listing
       await shallPass(cancelListing(Bob, listingIds[0]))
       listingIds = await getListingIds(Bob)
       expect(listingIds.length).toBe(0)

       await shallPass(listForFlow(Bob, bobsVaultIds[0], 50, 0.2))
       listingIds = await getListingIds(Bob)
       expect(listingIds[0]).toBe(2)

       await purchaseFlowListing(Alice, listingIds[0], Bob, 10)

       alicesFractions = await getFractionCollectionIds(Alice)
       expect(alicesFractions.length).toBe(100)

	});
    

})
