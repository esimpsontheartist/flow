import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getVaultAdminAddress } from "./common";


// CONTRACT DEPLOYMENT

/*
 * Deploys the Basket Collection contract, allowing multiple
 * NFTs to be held under the same collection while keeping
 * some of their information
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */
export const deployBasket = async () => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");

	let addressMap = {
		NonFungibleToken: VaultAdmin
	}

	return deployContractByName({ to: VaultAdmin, name: "Basket", addressMap });
};

// STATE MUTATION (TRANSACTIONS)

/*
 * Sets up Basket on account and exposes public capability.
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const setupBasketOnAccount = async (account) => {
	const name = "basket/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};


//Wraps an ExampleNFT as a Wrapped NFT
export const wrap = async(account, nftIds) => {
	const name = "basket/wrap";
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
export const getBasketCollectionIds = async (address) => {
	const name = "basket/get_collection_ids";
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
	const name = "basket/get_wnft";
	const args = [address, itemID];

	return executeScript({ name, args });
};



