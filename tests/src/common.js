import { getAccountAddress } from "flow-js-testing";

const UFIX64_PRECISION = 8;

// UFix64 values shall be always passed as strings
export const toUFix64 = (value) => value.toFixed(UFIX64_PRECISION);
// Address that manages the vaults
export const getVaultAdminAddress = async () => getAccountAddress("FractionalVaultAdmin");
// Address where the vault resource is minted to
export const getVaultAddress = async () => getAccountAddress("FractionalVaultOwner");
// Mock address for testing
export const getBobsAddress = async () => getAccountAddress("Bob");