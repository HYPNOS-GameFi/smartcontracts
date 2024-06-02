## Foundry


## Main Automates:

Hypnos Game Amoy: https://automation.chain.link/polygon-amoy/96646351574059379545416646064274307561935274400147411719306316933619167811724

Pool Sepolia: https://automation.chain.link/sepolia/35667175353810308141850493552014209167932615433147941566948508265442785513641

- Airdrop Avalanche Fuji:
https://automation.chain.link/fuji/109114246676473491058614847824060380045716675118188692697178175428201238975692

## Main VRFs

Polygon Amoy: https://vrf.chain.link/polygon-amoy/51993705499517109063832034032218776670133583656275697804326118989428630673606


## Second Automates (sub-rede):

- Polygon Amoy - PoolGame: https://automation.chain.link/polygon-amoy/52424363165676939154904242497028627549788525643488724318262096149633446465396
//owner: 0x5bb7dd6a6eb4a440d6C70e1165243190295e290B

- Ethereum Sepolia - HypnosGame: https://automation.chain.link/sepolia/57463112359095659235238801442621312240599076074831294587969368756242564523084

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

**Olhar os seguintes repositorios**: 
- https://github.com/ethercats/degeneratefarm/blob/main/contract.sol
- https://github.com/gelatodigital/vrf-nft/tree/main/src/vendor
- https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number

**Projetos que estoiu pegando de referencia para melhorar**
- https://tititi.gitbook.io/tititi-nft-research-labs/incentive/erc6551-incentive-program

instalar a seguinte library do ccip:

```javascript
forge install smartcontractkit/ccip@b06a3c2eecb9892ec6f76a015624413fffa1a122 --no-commit
```

```javascript
forge install https://github.com/smartcontractkit/chainlink-brownie-contracts --no-commit
```

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
