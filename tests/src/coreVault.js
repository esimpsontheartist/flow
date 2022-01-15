import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getVaultAdminAddress } from "./common";
import { deployFraction } from "./fraction";


// CONTRACT DEPLOYMENT

/*
 * Deploys the Core Vault contract to the admin
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 */
export const deployCoreVault = async () => {
	const VaultAdmin = await getVaultAdminAddress();
	await mintFlow(VaultAdmin, "10.0");

	await deployFraction()

	const addressMap = { 
		NonFungibleToken: VaultAdmin,
        Fraction: VaultAdmin
	}

	return deployContractByName({ to: VaultAdmin, name: "CoreVault", addressMap });
};

// STATE MUTATION (TRANSACTIONS)

/*
 * Sets up Core Vault on account
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const setupCoreVaultOnAccount = async (account) => {
	const name = "coreVault/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

/*
 * Mints a Core Vault
 * @param {UInt64} nftId - the id for an NFT (currently only supports Example NFT)
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const mintCoreVault = async (account ,nftIds) => {

	const name = "coreVault/mint_vault";
	const args = [
		nftIds
	];
	const signers = [account];

	return sendTransaction({ name, args, signers, limit: 9999 });
};

// SCRIPTS

/*
 * Returns the number of vaults that have been created
 * Same as "totalSupply" of vaults
 * @param none
 * @throws Will throw an error if execution will be halted
 * @returns {UInt256}
 * */
export const getCoreVaultCount = async () => {
	const name = "coreVault/get_vaultCount";
	const args = [];

	return executeScript({ name, args });
};

/*
 * Returns a Vault given an id
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {Vault?}
 * Vault = {
 * 	pub let vaultId: UInt64
    pub let curator: Address
    pub let collectionIds: [UInt64]
    pub let underlyingType: Type
    pub let name: String?
    pub let description: String?
 * }
 * */
export const getCoreVault = async (address, vaultId) => {
	const name = "coreVault/get_vault";
	const args = [
        address,
        vaultId
    ];

	return executeScript({ name, args });
};

/*
 * Returns an array with all the vault uuids owned by a user
 * @param {Address} - address
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]}
 * */
export const getCoreVaultIds = async (address) => {
	const name = "coreVault/get_collectionIds";
	const args = [address];

	return executeScript({ name, args });
};


/*
 * Returns the ids held by the underlying collection inside of the vault
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]?}
 * */
export const getCoreVaultUnderlyingIds = async (address, vaultId) => {
	const name = "coreVault/get_underlyingIds";
	const args = [
        address,
        vaultId
    ];

	return executeScript({ name, args });
};

