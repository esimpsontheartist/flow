import { getAccountAddress, executeScript } from "flow-js-testing";

const UFIX64_PRECISION = 8;

// UFix64 values shall be always passed as strings
export const toUFix64 = (value) => value.toFixed(UFIX64_PRECISION);
// Get the storage used by an account
export const getStorageUsed = (address) => executeScript({ name: "account/storage_used", args: [address]})
// Address that manages the vaults
export const getVaultAdminAddress = async () => getAccountAddress("FractionalVaultAdmin");
// Mock address for testing
export const getBobsAddress = async () => getAccountAddress("Bob");
// Mock secondary address for testing
export const getAlicesAddress = async () => getAccountAddress("Alice");
// Third Mock address for testing
export const getCarolsAddress = async () => getAccountAddress("Carol");
// Fourth mock address 
export const getDicksAddress = async () => getAccountAddress("Dick");