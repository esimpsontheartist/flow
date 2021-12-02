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


//Wraps an ExampleNFT as a Wrapped NFT
export const wrap = async(account, nftIds) => {
	const name = "wnft/wrap";
	const args = [nftIds]
	const signers = [account]

	return sendTransaction({ name, args, signers, limit: 9999 });
}	

/*
 * Returns an array with all the wnft ids owned by an account
 * @param {Address} - address
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]}
 * */
export const getWNFTCollectionIds = async (address) => {
	const name = "wnft/get_collection_ids";
	const args = [address];

	return executeScript({ name, args });
};

/*
 * Returns data of wnft given an id
 * @param {Address} - address
 * @throws Will throw an error if execution will be halted
 * @returns {AccountItem?}
 * AccountItem = {
 * 	itemID: UInt64
 *  resourceID: UInt64
 *  owner: Address
 * */
export const getWNFT = async (address, itemID) => {
	const name = "wnft/get_wnft";
	const args = [address, itemID];

	return executeScript({ name, args });
};



