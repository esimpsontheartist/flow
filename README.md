# Fractional Flow Contracts

[Fractional](https://fractional.art/) contracts for the Flow blockchain.

- Smart contracts written in [Cadence](https://docs.onflow.org/cadence).
- Tests and scripts written in js using the [flow js testing library](https://docs.onflow.org/flow-js-testing/)

## Addresses

| Contract               | Testnet              |
|------------------------|----------------------|
| EnumerableSet          | `...`                |
| WrappedCollection      | `...`                |
| PriceBook              | `...`                |
| Fraction               | `...`                |
| FractionalVault        | `...`                |
| FractionFixedPriceSale | `...`                |
| VaultMetadata          | `...`                |


Additionally, an `ExampleNFT` contract was deployed to the address above for testing purposes (emulator and testnet only).

## Smart contracts

`EnumerableSet`: An implementation of Openzeppelin's [EnumberableSet](https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet) in Cadence.

`WrappedCollection`: A custom NFT collection that wraps NFTs in order to preserve some data about them.

`PriceBook`: A contract that handles all the logic behind calculating the reserve price for a vault.

`Fraction`: An NFT contract to represent vault fractions as NFTs.

`FractionalVault`: The main contract, defines the `Vault` resource, which holds can hold one or many NFTs for a given collection through [Run-time types](https://docs.onflow.org/cadence/language/run-time-types/#gatsby-focus-wrapper) or a collection of different NFTs through the `WrappedCollection.Collection` resource.

`FractionFixedPriceSale`: A contract that allows a vault curator to

## Directory structure

The directory is divided into different folders, mainly:

- `contracts/`: where all the contracts live
- `transactions/`: contains all transactions used for testnet/mainnet interaction live
- `scripts/`: contains scripts to query data from the contracts
- `tests/`: contains all the files used for testing, including a separate set of `contracts`, `transactions`, and `scripts`

## Front End interaction

To build a front end that interacts with the contracts using js, please refer to the [flow-app-quickstart](https://docs.onflow.org/fcl/tutorials/flow-app-quickstart/) page to learn more about using the flow-js sdk, and to [Blocto's Docs](https://docs.blocto.app/blocto-sdk/flow/tutorial) to find more about using the blocto wallet in the app.
