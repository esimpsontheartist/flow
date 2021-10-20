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

	return deployContractByName({ to: VaultAdmin, name: "EnumerableSet" });
};