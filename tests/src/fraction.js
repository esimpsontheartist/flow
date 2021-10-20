import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getVaultAdminAddress } from "./common";


// CONTRACT DEPLOYMENT

/*
 * Deploys the Fraction contract to the Vault Admin
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const deployFraction = async () => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");

	return deployContractByName({ to: VaultAdmin, name: "Fraction" });
};

// STATE MUTATION (TRANSACTIONS)

/*
 * Sets up Fraction.Collection on account and exposes public capability.
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const setupFractionOnAccount = async (account) => {
	const name = "fraction/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

/*
 * Transfers an **amount** of Fractions from **sender** account to **recipient**.
 * @param {string} sender - sender address
 * @param {string} recipient - recipient address
 * @param {[UInt64]} withdrawIDs - [UInt64] IDs of fractions to transfer
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const transferFractions = async (sender, recipient, withdrawIDs) => {
	const name = "fraction/transfer_fractions";
	const args = [recipient, withdrawIDs];
	const signers = [sender];

	return sendTransaction({ name, args, signers });
};

// SCRIPTS

/*
 * Returns the number of fractions owned by an account (exclusive of vaultId)
 * @param {Address} - address
 * @throws Will throw an error if execution will be halted
 * @returns {UInt256}
 * */
export const getCollectionBalance = async (address) => {
	const name = "fraction/get_collection_balance";
	const args = [address];

	return executeScript({ name, args });
};

/*
 * Returns an array with all the fraction ids owned by an account
 * @param {Address} - address
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]}
 * */
export const getCollectionIds = async (address) => {
	const name = "fraction/get_collection_ids";
	const args = [address];

	return executeScript({ name, args });
};

/*
 * Returns an the total count of all fractions sets that have existed
 * @param none
 * @throws Will throw an error if execution will be halted
 * @returns {UInt256}
 * */
export const getCount = async () => {
	const name = "fraction/get_count";
	const args = [];

	return executeScript({ name, args });
};

/*
 * Returns an the total count of all fractions currently in existence for a given vaultId
 * @param {UInt256} - vaultId
 * @throws Will throw an error if execution will be halted
 * @returns {UInt256}
 * */
export const getFractionSupply = async (vaultId) => {
	const name = "fraction/get_count";
	const args = [vaultId];

	return executeScript({ name, args });
};

/*
 * Returns an array with all the fraction ids owned by an account given a vaultId
 * @param {Address} - address
 * @param {UInt256} - vaultId
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]}
 * */
export const getFractionsByVault = async (address, vaultId) => {
	const name = "fraction/get_collection_ids";
	const args = [address, vaultId];

	return executeScript({ name, args });
};

/*
 * Returns an the total supply of all fractions currently in existance
 * @param none
 * @throws Will throw an error if execution will be halted
 * @returns {UInt64}
 * */
export const getCount = async () => {
	const name = "fraction/get_totalSupply";
	const args = [];

	return executeScript({ name, args });
};