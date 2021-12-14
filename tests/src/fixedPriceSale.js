import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getVaultAdminAddress } from "./common";
import { deployFraction } from "./fraction";
import { deployFractionalVault } from "./fractionalVault";

// CONTRACT DEPLOYMENT

/*
 * Deploys the Fraction contract to the Vault Admin
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */
export const deployFixedPriceSale = async () => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");

	await deployFractionalVault()

	const addressMap = { 
		NonFungibleToken: VaultAdmin,
		Fraction: VaultAdmin,
		FractionalVault: VaultAdmin
	}

	return deployContractByName({ to: VaultAdmin, name: "FractionFixedPriceSale", addressMap });
};

// STATE MUTATION (TRANSACTIONS)

/*
 * Sets up FixedSaleCollection on account and exposes public capability.
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const setupFixedPricesaleOnAccount = async (account) => {
	const name = "fixedPriceSale/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};


/*
 * Lists a set of fractions for sale if the signer is the curator of a vault
 * */
export const listForFlow = async (sender, vaultId, amount, salePrice) => {
	const name = "fixedPriceSale/list_flow";
	const args = [vaultId, amount, salePrice];
	const signers = [sender];

	return sendTransaction({ name, args, signers, limit: 9999});
};

/*
 * Purchases a listing of fractions and pays flow
 * */
export const purchaseFlowListing = async (signer, listingId, seller, amount) => {
	const name = "fixedPriceSale/purchase_listing_flow";
	const args = [listingId, seller, amount];
	const signers = [signer];

	return sendTransaction({ name, args, signers, limit: 9999});
};

/*
 * Cancels a listing if the signer is the curator for the given vaultId
 * */
export const cancelListing = async (signer, listingId,) => {
	const name = "fixedPriceSale/cancel_listing";
	const args = [listingId];
	const signers = [signer];

	return sendTransaction({ name, args, signers, limit: 9999});
};

// SCRIPTS



/*
 * Returns the listing ids a fixedSaleCollection has
 * @param none
 * @throws Will throw an error if execution will be halted
 * @returns ids [UInt64]
 * */
export const getListingIds = async (address) => {
	const name = "fixedPriceSale/get_ids";
	const args = [address];

	return executeScript({ name, args });
};

/*
 * Returns a data for a fraction listing
 * @param none
 * @throws Will throw an error if execution will be halted
 * @returns {FractionData}
 * */
export const getListingData = async (listingId) => {
	const name = "fixedPriceSale/get_fractionData";
	const args = [listingId];

	return executeScript({ name, args });
};