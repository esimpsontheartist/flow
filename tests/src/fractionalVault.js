import { deployContractByName, executeScript, mintFlow, sendTransaction, getContractAddress } from "flow-js-testing";
import { getVaultAdminAddress, getVaultAddress } from "./common";
import { deployFraction } from "./fraction";



// CONTRACT DEPLOYMENT

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


	await deployFraction()
	await deployContractByName({ to: VaultAdmin, name: "WrappedCollection", addressMap: {NonFungibleToken: VaultAdmin} });
	await deployContractByName({ to: VaultAdmin, name: "Clock"})
	const addressMap = { 
		NonFungibleToken: VaultAdmin,
		PriceBook: VaultAdmin,
		Fraction: VaultAdmin,
		WrappedCollection: VaultAdmin,
		Clock: VaultAdmin
	}

	return deployContractByName({ to: VaultAdmin, name: "FractionalVault", addressMap: addressMap, args: [VaultAddress] });
};

// STATE MUTATION (TRANSACTIONS)

/*
 * Sets up Fractional Vault on account and exposes public capability.
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
export const mintVault = async (
	account, 
	nftIds, 
	curator, 
	maxSupply
) => {

	const name = "vault/mint_vault";
	const args = [
		nftIds, 
		curator, 
		maxSupply
	];
	const signers = [account];

	return sendTransaction({ name, args, signers, limit: 9999 });
};

/*
 * Mints a fractional vault for a given set of NFTs (currently only working with ExampleNFT)
 * @param {UInt64} nftId - the id for an NFT (currently only supports Example NFT)
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const mintVaultFractions = async (signer, vaultId) => {

	const name = "vault/mint_vaultFractions";
	const args = [vaultId];
	const signers = [signer];

	return sendTransaction({ name, args, signers, limit: 9999 });
};



/*
 * Calls the start() function to kickoff an auction
 * @param {Address} signer - the address to signt the transaction
 * @param {UInt256} vaultId - the id for a vault 
 * @param {UFix64} amount - amount of FLOW to bid for the underlying
 * ^ (will revert if amount < reservePrice)
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const start = async (signer, vaultId, amount) => {

	const name = "vault/start";
	const args = [vaultId, amount]
	const signers = [signer]

	return sendTransaction({ name, args, signers })
}


/*
 * Calls the end() function to end an auction after the timer has run out
 * @param {Address} signer - the address to signt the transaction
 * @param {UInt256} vaultId - the id for a vault 
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const end = async (signer, vaultId) => {

	const name = "vault/end";
	const args = [vaultId]
	const signers = [signer]

	return sendTransaction({ name, args, signers })
}

/*
 * Sends a bid to the vault for a possible settlement for the underlying collection
 * @param {Address} signer - the address to signt the transaction
 * @param {UInt256} vaultId - the id for a vault 
 * @param {UFix64} amount - amount of FLOW to bid for the underlying
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const bid = async (signer, vaultId, amount) => {

	const name = "vault/bid";
	const args = [vaultId, amount]
	const signers = [signer]

	return sendTransaction({ name, args, signers })
}

/*
 * Calls the cash() function in order to receive FLOW in exchange for fractions
 * after an auction has been settled
 * @param {Address} signer - the address to signt the transaction
 * @param {UInt256} vaultId - the id for a vault 
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const cash = async (signer, vaultId, fractionIds) => {

	const name = "vault/cash";
	const args = [vaultId, fractionIds]
	const signers = [signer]

	return sendTransaction({ name, args, signers, limit: 9999 })
}

/*
 * Calls the redeem() function in order to transfer the fractions a signer has
 * in exchange for the underlying, if the signer does not have all the fractions
 * the transaction will fail
 * @param {Address} signer - the address to signt the transaction
 * @param {UInt256} vaultId - the id for a vault 
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const redeem = async (signer, vaultId, amount) => {

	const name = "vault/redeem";
	const args = [vaultId, amount]
	const signers = [signer]

	return sendTransaction({ name, args, signers, limit: 9999 })
}

/*
 * Calls the updateFractionPrice() function 
 * in order to update the fractions' owner desired reserve price
 * @param {Address} signer - the address to signt the transaction
 * @param {UInt256} vaultId - the id for a vault 
 * @param {UFix64} newPrice - the new price the fractions are "voting" for
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const updatePrice = async (signer, vaultId, startId, amount, newPrice) => {

	const name = "vault/update_price";
	const args = [vaultId, startId, amount, newPrice]
	const signers = [signer]

	return sendTransaction({ name, args, signers, limit: 9999 })
}

/**
 * A function to tick the Clock (testing purposes only)
 */
 export const tickClock = async(time) => {
	const name = "clock/tick";
	const args = [time]
	const VaultAddress = await getVaultAddress()
	const signers = [VaultAddress]

	return sendTransaction({ name, args, signers})
 }

// SCRIPTS

/*
 * Returns the number of vaults that have been created
 * Same as "totalSupply" of vaults
 * @param none
 * @throws Will throw an error if execution will be halted
 * @returns {UInt256}
 * */
export const getVaultCount = async () => {
	const name = "vault/get_vaultCount";
	const args = [];

	return executeScript({ name, args });
};

/*
 * Returns a Vault given an id
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {Vault?}
 * Vault = {
 * 	vaultId: UInt256
 *  auctionEnd: UFix64?
 *  auctionLength: uFix64
 *  livePrice: UFix64?
 *  winning: Address?
 *  resourceID: UInt64
 *  vaultAddress: Address
 * }
 * */
export const getVault = async (vaultId) => {
	const name = "vault/get_vault";
	const args = [vaultId];

	return executeScript({ name, args });
};

/*
 * Returns the balance of the Vault's bid vault
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {UFix64}
 * */
export const getBidVaultBalance = async (vaultId) => {
	const name = "vault/get_bidVaultBalance";
	const VaultAddress = await getVaultAddress();
	const args = [VaultAddress, vaultId];

	return executeScript({ name, args });
};


/*
 * Returns the ids of the fractions that the vault has
 * Same as seeing how many fractions have been sent for cashing
 * Can also be used to check if a vault has been redeemed
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]?}
 * */
export const getFractionIds = async (vaultId) => {
	const name = "vault/get_fractionIds";
	const args = [vaultId];

	return executeScript({ name, args });
};

/*
 * Returns the UUIDs of the underlying NFTs in the collection
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]?}
 * */
export const getUnderlyingCollectionIds = async (vaultId) => {
	const name = "vault/get_underlyingCollectionIds";
	const args = [vaultId];

	return executeScript({ name, args });
};

/*
 * Returns an NFT (according to the flow standard) from the underlying collection
 * @param {UInt256} vaultId - the vaults id
 * @param {UInt64} itemUUID - the nft's UUID
 * @throws Will throw an error if execution will be halted
 * @returns {NFT?}
 * NFT = {
 * 	id: UInt64
 * }
 * */
export const getUnderlyingNFT = async (vaultId, itemUUID) => {
	const name = "vault/get_underlyingNFT";
	const args = [vaultId, itemUUID];

	return executeScript({ name, args });
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
	const name = "priceBook/get_reserveInfo";
	const args = [vaultId];

	return executeScript({ name, args });
};






 