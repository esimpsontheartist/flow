import path from "path";

import { 
    emulator, 
    init,
    getServiceAddress,
    deployContract,
    executeScript,
    getAccountAddress,
    shallPass,
    shallResolve,
    shallRevert 
} from "flow-js-testing";
import { getVaultAdminAddress, getVaultAddress, getBobsAddress } from "../src/common";
import {
    deployFraction,
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
    getFractionIds,
    getUnderlyingCollectionIds,
    getUnderlyingNFT,
    getUnderlyingWNFT
} from "../src/fractionalVault"

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(500000);

describe("FractionalVault", () => {

    // Instantiate emulator and path to Cadence files
	beforeEach(async () => {
		const basePath = path.resolve(__dirname, "../../");
		const port = 7001;
		await init(basePath, { port });
		return emulator.start(port, false);
	});

    // Stop emulator, so it could be restarted
	afterEach(async () => {
		return emulator.stop();
	});

    //Common Functionality

    it("shall deploy FractionalVault contract", async () => {
		await deployFractionalVault();
	});

    it("shall setup fractionalVault on account ", async () => {
		await deployFractionalVault();
        //const VaultAddress = await getVaultAddress()
        //VaultAddress is hard coded for now
        await shallPass(setupVaultOnAccount("0x179b6b1cb6755e31"));
	});

    it("count shall be 0 after deployment", async () => {
		await deployFractionalVault();
        const VaultAddress = await getVaultAddress()
        //VaultAddress is hard coded for now
        await shallPass(setupVaultOnAccount(VaultAddress));
        let count = await getVaultCount()
        expect(count).toBe(0);
	});

    it("mints an example nft to be used in a vault", async () => {
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        let ids = await getExampleNFTCollectionIds(Bob)
	});

    it("shall be able to mint a vault", async () => {
		// Setup
		await deployFractionalVault();
        const VaultAdmin = await getVaultAdminAddress()
		await deployExampleNFT(VaultAdmin);
        const Bob = await getBobsAddress()
        await shallPass(setupExampleNFTOnAccount(Bob))
        await shallPass(mintExampleNFT(Bob, Bob))
        let ids = await getExampleNFTCollectionIds(Bob)
        const VaultAddress = await getVaultAddress()
        await shallPass(setupVaultOnAccount(VaultAddress));
        //setup fraction collection
        await shallPass(setupFractionOnAccount(Bob))
        //Bob mints a vault
        await shallPass(mintVault(Bob, ids[0], Bob))
        //Add expect(var).toBe()
	});

    // Vaults auction functionality


})
