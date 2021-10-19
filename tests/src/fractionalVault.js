import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getVaultAdminAddress, getVaultAddress } from "./common";

/*
 * Deploys Fractional Vault contract to FractionalVaultAdmin.
 * @param {address} vaultAddress - the address where the vault resources is minted to
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const deployFractionalVault = async () => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");
    const VaultAddress = await getVaultAddress();
    await mintFlow(VaultAddress, "10.0");

	return deployContractByName({ to: VaultAdmin, name: "FractionalVault", args: [VaultAddress] });
};

/*
 * Setups Fractional Vault on account and exposes public capability.
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const setupVaultOnAccount = async (account) => {
	const name = "vault/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

/*
 * Mints a fractional vault for a given set of NFTs (currently only working with ExampleNFT)
 * @param {UInt64} nftId - the id for an NFT (currently only supports Example NFT)
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const mintVault = async (nftId) => {
	const VaultAdmin = await getVaultAdminAddress();

	const name = "vault/mint_vault";
	const args = [nftId];
	const signers = [VaultAdmin];

	return sendTransaction({ name, args, signers });
};



/*
 * Returns Kibble balance for **account**.
 * @param {string} account - account address
 * @throws Will throw an error if execution will be halted
 * @returns {UFix64}
 * */
export const getKibbleBalance = async (account) => {
	const name = "kibble/get_balance";
	const args = [account];

	return executeScript({ name, args });
};

/*
 * Returns Kibble supply.
 * @throws Will throw an error if execution will be halted
 * @returns {UFix64}
 * */
export const getKibbleSupply = async () => {
	const name = "kibble/get_supply";
	return executeScript({ name });
};


