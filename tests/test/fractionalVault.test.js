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

import { getVaultAdminAddress, getVaultAddress } from "../src/common";

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

    it("shall deploy FractionalVault contract", async () => {
		await deployFractionalVault();
	});

    it("shall setup fractionalVault on account ", async () => {
		await deployFractionalVault();
        const VaultAddress = await getVaultAddress()
        console.log("VaultAddress: ", VaultAddress)
        await shallPass(setupVaultOnAccount(0x179b6b1cb6755e31));
	});


})
