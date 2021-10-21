import { deployContractByName, mintFlow } from "flow-js-testing";
import { getVaultAdminAddress } from "./common";


// CONTRACT DEPLOYMENT

/*
 * Deploys the EnumerableSet contract
 * as well as wrapping nfts.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */
export const deployEnumberableSet = async () => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");

	return deployContractByName({ to: VaultAdmin, name: "PriceBook" });
};

/*
 * Returns reserve information for a vault given it's id
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {ReserveInfo}
 * ReserveInfo = {
 * 	voting: UInt256
 * 	reserve: UFix64
 * }
 * */
export const getReserveInfo = async (vaultId) => {
	const name = "priceBook/get_resereverInfo";
	const args = [vaultId];

	return executeScript({ name, args });
};
