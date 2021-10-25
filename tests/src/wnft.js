import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getVaultAdminAddress } from "./common";


// CONTRACT DEPLOYMENT

/*
 * Deploys the Wrapped Collection contract, allowing for WNFT use
 * as well as wrapping nfts.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */
export const deployWrappedCollection = async () => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");

	await deployContractByName({ to: VaultAdmin, name: "NonFungibleToken" });

	let addressMap = {
		NonFungibleToken: VaultAdmin
	}

	return deployContractByName({ to: VaultAdmin, name: "WrappedCollection", addressMap });
};

// STATE MUTATION (TRANSACTIONS)

/*
 * Sets up WrappedCollection on account and exposes public capability.
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const setupWrappedCollectionOnAccount = async (account) => {
	const name = "wnft/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

