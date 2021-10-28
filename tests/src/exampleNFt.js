import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getVaultAdminAddress } from "./common";


// CONTRACT DEPLOYMENT

/*
 * Deploys the ExampleNFT contract to the Vault Admin
 * This NFT is just a mock for local and testnet interactions
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */
export const deployExampleNFT = async (address) => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");
	
	return deployContractByName({ to: VaultAdmin, name: "ExampleNFT", addressMap: {NonFungibleToken: address} });
};

// STATE MUTATION (TRANSACTIONS)

/*
 * Sets up ExampleNFT.Collection on account and exposes public capability.
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const setupExampleNFTOnAccount = async (account) => {
	const name = "nft/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

/*
 * Mints an ExampleNFT
 * @param {UInt64} nftId - the id for an exampleNFT to be minted
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const mintExampleNFT = async (sender, recipient) => {

	const name = "nft/mint_exampleNFT";
	const args = [recipient];
	const signers = [sender];

	return sendTransaction({ name, args, signers });
};

/*
 * Transfers an **amount** of ExampleNFTs from **sender** account to **recipient**.
 * @param {string} sender - sender address
 * @param {string} recipient - recipient address
 * @param {[UInt64]} withdrawIDs - [UInt64] IDs of fractions to transfer
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const transferExampleNFT = async (sender, recipient, withdrawIDs) => {
	const name = "nft/transfer_exampleNFTs";
	const args = [recipient, withdrawIDs];
	const signers = [sender];

	return sendTransaction({ name, args, signers });
};

// SCRIPTS

/*
 * Returns an array with all the exampleNFT ids owned by an account
 * @param {Address} - address
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]}
 * */
export const getExampleNFTCollectionIds = async (address) => {
	const name = "nft/get_collection_ids";
	const args = [address];

	return executeScript({ name, args });
};

/*
 * Returns the size of an account's colelction
 * @param {Address} - address
 * @throws Will throw an error if execution will be halted
 * @returns {Int}
 * */
export const getCollectionLength = async (address) => {
	const name = "nft/get_collection_length";
	const args = [address];

	return executeScript({ name, args });
};

/*
 * Returns data of an example NFT given an id
 * @param {Address} - address
 * @throws Will throw an error if execution will be halted
 * @returns {AccountItem?}
 * AccountItem = {
 * 	itemID: UInt64
 *  resourceID: UInt64
 *  owner: Address
 * */
export const getNFT = async (address, itemID) => {
	const name = "nft/get_nft";
	const args = [address, itemID];

	return executeScript({ name, args });
};