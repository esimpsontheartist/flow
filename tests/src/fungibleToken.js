import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getVaultAdminAddress } from "./common";


// CONTRACT DEPLOYMENT

/*
 * Deploys the Wrapped Collection contract, allowing for WNFT use
 * as well as wrapping nfts.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */
export const deployFungibleToken= async () => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");

	return deployContractByName({ to: VaultAdmin, name: "FungibleToken" });
};