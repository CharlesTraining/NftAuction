## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

```shell
$ forge script script/Deploy.s.sol:Deploy \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

### Test Deployed Contracts

Set common addresses:

```shell
export AUCTION_FACTORY_PROXY=0x...
export NFT_MARKET=0x...
```

Read deployment state:

```shell
forge script script/TestDeployedInterfaces.s.sol:CheckDeployment --rpc-url sepolia
```

Mint an NFT and create an ETH auction:

```shell
export PRIVATE_KEY=...
export TOKEN_URI=ipfs://demo-token
export AUCTION_DURATION_HOURS=1
export RESERVE_PRICE_USD=1000000000

forge script script/TestDeployedInterfaces.s.sol:MintAndCreateEthAuction \
    --rpc-url sepolia \
    --broadcast
```

Bid with ETH:

```shell
export BIDDER_PRIVATE_KEY=...
export AUCTION_ID=1
export BID_ETH_WEI=1000000000000000000

forge script script/TestDeployedInterfaces.s.sol:BidEthAuction \
    --rpc-url sepolia \
    --broadcast
```

Read an auction:

```shell
export AUCTION_ID=1
forge script script/TestDeployedInterfaces.s.sol:ReadAuction --rpc-url sepolia
```

End an auction after `endTime`:

```shell
export PRIVATE_KEY=...
export AUCTION_ID=1

forge script script/TestDeployedInterfaces.s.sol:EndAuction \
    --rpc-url sepolia \
    --broadcast
```

For ERC20 auctions, first configure the token feed, then create and bid:

```shell
export PRIVATE_KEY=...
export BID_TOKEN=0x...
export TOKEN_USD_FEED=0x...

forge script script/TestDeployedInterfaces.s.sol:SetERC20Feed \
    --rpc-url sepolia \
    --broadcast

forge script script/TestDeployedInterfaces.s.sol:MintAndCreateERC20Auction \
    --rpc-url sepolia \
    --broadcast

export BIDDER_PRIVATE_KEY=...
export AUCTION_ID=2
export BID_TOKEN_AMOUNT=1000000000000000000000

forge script script/TestDeployedInterfaces.s.sol:BidERC20Auction \
    --rpc-url sepolia \
    --broadcast
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

