import { deployContractByName, executeScript, mintFlow, sendTransaction, getContractAddress } from "flow-js-testing";
import { getVaultAdminAddress} from "./common";
import { deployCoreVault } from "./coreVault";



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


	await deployCoreVault()
	await deployContractByName({ to: VaultAdmin, name: "Modules", addressMap: {
		NonFungibleToken: VaultAdmin,
		Fraction: VaultAdmin
	}})
	await deployContractByName({ to: VaultAdmin, name: "Utils"});
	await deployContractByName({ to: VaultAdmin, name: "Clock"})

	const addressMap = { 
		NonFungibleToken: VaultAdmin,
		EnumerableSet: VaultAdmin,
		CoreVault: VaultAdmin,
		Modules: VaultAdmin,
		Fraction: VaultAdmin,
		Utils: VaultAdmin,
		Clock: VaultAdmin
	}

	return deployContractByName({ to: VaultAdmin, name: "FractionalVault", addressMap: addressMap});
};

// STATE MUTATION (TRANSACTIONS)

/*
 * Sets up Fractional Vault on account and exposes public capability.
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const setupVaultOnAccount = async (account) => {
	const name = "fractionalVault/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

/*
 * Mints a fractional vault for a given CoreVault
 * @param {UInt64} nftId - the id for an NFT (currently only supports Example NFT)
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const mintVault = async (
	account,
	vaultId,
	maxSupply
) => {

	const name = "fractionalVault/mint_vault";
	const args = [
		vaultId, 
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
export const mintVaultFractions = async (signer, recipient, vaultId, amount) => {

	const name = "fractionalVault/mint_vaultFractions";
	const args = [recipient, vaultId, amount];
	const signers = [signer];

	return sendTransaction({ name, args, signers, limit: 9999 });
};



/*
 * Calls the start() function to kickoff an auction
 * @param {Address} signer - the address to signt the transaction
 * @param {Address} address - the address to get the vault from
 * @param {UInt256} vaultId - the id for a vault 
 * @param {UFix64} amount - amount of FLOW to bid for the underlying
 * ^ (will revert if amount < reservePrice)
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<*>}
 * */
export const start = async (signer, address, vaultId, amount) => {

	const name = "fractionalVault/start";
	const args = [address, vaultId, amount]
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
export const end = async (signer, address, vaultId) => {

	const name = "fractionalVault/end";
	const args = [address, vaultId]
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
export const bid = async (signer, address, vaultId, amount) => {

	const name = "fractionalVault/bid";
	const args = [address, vaultId, amount]
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
export const cash = async (signer, address, vaultId) => {

	const name = "fractionalVault/cash";
	const args = [address, vaultId]
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
export const redeem = async (signer, address, vaultId) => {

	const name = "fractionalVault/redeem";
	const args = [address, vaultId]
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
export const updateUserPrice = async (signer, address, vaultId, newPrice) => {

	const name = "fractionalVault/update_price";
	const args = [address, vaultId, newPrice]
	const signers = [signer]

	return sendTransaction({ name, args, signers, limit: 9999 })
}

/**
 * A function that allows the contract owner to set a fee 
 * that is taken out of the winning bid of a FractionalVault
 * @param {Address} signer 
 * @param {Bool} hasFee 
 * @returns 
 */
export const manageVaultFee = async(signer, fee) => {
	const name = "fractionalVault/manageVaultFee";
	const args = [fee]
	const signers = [signer]

	return sendTransaction({ name, args, signers, limit: 9999 })
}

export const overrideBidVaultPath = async(signer, address, vaultId) => {
	const name = "fractionalVault/overrideBidVaultPath";
	const args = [address, vaultId]
	const signers = [signer]

	return sendTransaction({ name, args, signers, limit: 9999 })
}

export const badOverrideBidVaultPath = async(signer, address, vaultId) => {
	const name = "fractionalVault/badOverrideBidVaultPath";
	const args = [address, vaultId]
	const signers = [signer]

	return sendTransaction({ name, args, signers, limit: 9999 })
}

export const withdrawVault = async(signer, vaultId) =>  {
	const name = "fractionalVault/withdrawVault";
	const args = [vaultId]
	const signers = [signer]

	return sendTransaction({ name, args, signers, limit: 9999 })
}

/**
 * A function to tick the Clock (testing purposes only)
 */
 export const tickClock = async(time) => {
	const name = "clock/tick";
	const args = [time]
	const VaultAdmin = await getVaultAdminAddress()
	const signers = [VaultAdmin]

	return sendTransaction({ name, args, signers})
 }



// SCRIPTS

/**
 * A script to get the vaults owned by a FractionalVault Collection
 * @param {Address} address 
 */
export const getVaultIds = async(address) => {
	const name = "fractionalVault/get_collectionIds";
	const args = [address]

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
export const getVault = async (address, vaultId) => {
	const name = "fractionalVault/get_vault";
	const args = [address, vaultId];

	return executeScript({ name, args });
};

/*
 * Returns the balance of the Vault's bid vault
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {UFix64}
 * */
export const getBidVaultBalance = async (address, vaultId) => {
	const name = "fractionalVault/get_bidVaultBalance";
	const args = [address, vaultId];

	return executeScript({ name, args });
};


/*
 * Returns the UUIDs of the underlying NFTs in the collection
 * @param {UInt256} vaultId - the vaults id
 * @throws Will throw an error if execution will be halted
 * @returns {[UInt64]?}
 * */
export const getUnderlyingCollectionIds = async (address, vaultId) => {
	const name = "fractionalVault/get_underlyingCollectionIds";
	const args = [address, vaultId];

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
export const getUnderlyingNFT = async (address, vaultId, itemUUID) => {
	const name = "fractionalVault/get_underlyingNFT";
	const args = [address, vaultId, itemUUID];

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
	const name = "fractionalVault/get_reserveInfo";
	const args = [vaultId];

	return executeScript({ name, args });
};






 