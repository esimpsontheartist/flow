# Fractional Flow Contracts

[Fractional](https://fractional.art/) contracts for the Flow blockchain.

- Smart contracts written in [Cadence](https://docs.onflow.org/cadence).
- Tests and scripts written in js using the [flow js testing library](https://docs.onflow.org/flow-js-testing/)

## Addresses

| Contract               | Testnet              |
|------------------------|----------------------|
| EnumerableSet          | `0x64e254541a0d8623` |
| Basket                 | `0x64e254541a0d8623` |
| Utils                  | `0x64e254541a0d8623` |
| Fraction               | `0x64e254541a0d8623` |
| CoreVault              | `0x64e254541a0d8623` |
| Modules                | `0x64e254541a0d8623` |
| FractionalVault        | `0x64e254541a0d8623` |
| FixedPriceSale         | `0x64e254541a0d8623` |
| VaultMetadata          | `0x799c03fe4f8cf26b` |


An `ExampleNFT` contract was deployed to `0x64e254541a0d8623` for testing purposes (emulator and testnet only). Additionally, the contracts in the `third-party` folder have been deployed under `0x799c03fe4f8cf26b` for testnet
purposes

## Testing

To run the test suite, change directories to `tests/` and run `npm install` and `npm run tests`.

## Smart contracts

`EnumerableSet`: An implementation of Openzeppelin's [EnumberableSet](https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet) in Cadence.

`Basket`: A custom NFT collection that wraps NFTs in order to preserve some data about them, which allows NFTs from different collections to exist under 1.

`PriceBook`: A contract that handles all the logic behind calculating the reserve price for a vault.

`Utils`: A contract that defines utility functions for any other contracts to use.

`Fraction`: The contract that defines the Fraction standard by implementing the NonFungibleToken standard while having additional functionality geared towards the Fractional protocol.

`CoreVault`: The contract that defines the `Corevault.Vault` resource, used for holding NFTs and which also plugs into other contracts in the deployment address.

`Modules`: A contract that defines interfaces used by Fractional Protocol modules.

`FractionalVault`: The first Module for the CoreVault, defines the `FractionalVault.Vault` resource, which can hold one or many NFTs for a given collection through [Run-time types](https://docs.onflow.org/cadence/language/run-time-types/#gatsby-focus-wrapper) or a collection of different NFTs through the `Basket.Collection` resource. It also defines all the functionality that makes it similar to the [OG Fractional Solidity contracts](https://github.com/fractional-company/contracts)

`FixedPriceSale`: A contract that allows a Corevault owner that has used the `FractionalVault.Vault` resource to distribute fractions through a fixed price sale.

`VaultMetadata`: A contract meant to be used in testnet and production for scripts to be able to gather data otherwise not available through the NonFungibleToken interface by providing a restricted interface of a specific type to a given NFT that has been deposited to a vault.

## Directory structure

The directory is divided into different folders, mainly:

- `contracts/`: where all the contracts live
- `transactions/`: contains all transactions used for testnet/mainnet interaction.
- `scripts/`: contains scripts to query data from the contracts
- `tests/`: contains all the files used for testing, including a set of `contracts`, `transactions`, and `scripts` that use a `Clock.cdc` contract to mock time.

## Front End interaction

To build a front end that interacts with the contracts using js, please refer to the [flow-app-quickstart](https://docs.onflow.org/fcl/tutorials/flow-app-quickstart/) page to learn more about using the flow-js sdk, and to [Blocto's Docs](https://docs.blocto.app/blocto-sdk/flow/tutorial) to find more about using the blocto wallet in the app.
