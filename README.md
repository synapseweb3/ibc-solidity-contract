# IBC Solidity For Forcerelay

The IBC solidity contracts for [Axon](https://github.com/axonweb3/axon) is based on [yui-ibc-solidity](https://github.com/hyperledger-labs/yui-ibc-solidity). Most of the instructions, such as registering IBC modules and light client, remain the same.

NOTE: This is pre-beta non-production-quality software, not ready for use in a production environment.

## Limitation

`yui-ibc-solidity` is designed to be compatible with the IBC core protocol, providing minimal compatibility. In contrast, `ibc-solidity-contract` goes further by providing additional APIs to support Forcerelay's query and storage demands. Consequently, the contract size exceeds the limits imposed by standard EVM-compatible chains, such as Arbitrum, Avalanche, BSC. As a result, this project can only be deployed on Axon, taking advantage of Axon's ability to transcend the EVM's constraints.

## Installation and Testing

First, ensure that, Node.js and Yarn have been already installed:

```bash
$ git clone https://github.com/synapseweb3/ibc-solidity-contract
$ cd ibc-solidity-contract
$ yarn install
$ yarn compile
$ yarn test
```

## Deploy on Axon

Creating a `.env` file in the project root path:

```
AXON_HTTP_RPC_URL=http://<AXON_URL>:<HTTP_PORT>
AXON_WS_RPC_URL=ws://<AXON_URL>:<WS_PORT>
```

Then, use the migration command to deploy the contract and prepare basic settings for Axon:

```bash
$ yarn migrate
```

After deployment, each standalone component in the project has been migrated into Axon and the entry is `OwnableIBCHandler` contract, which accepts operations, including registering IBC module and binding channel port.

## Register Light Client

Registering light client is essential for verifying transactions from the counterparty chain. A mock light client has been registered into OwnableIBCHandler contract during the migration, which acts as an entry for counterparty.

While the official light clients for verifying Cosmos and CKB transactions are in development, you can use a custom light client by following the [method](https://github.com/synapseweb3/ibc-solidity-contract/blob/master/contracts/core/02-client/ILightClient.sol) below 

```solidity
function registerClient(string calldata clientType, ILightClient client)
```

Note: clientType here can be one of these values: “07-axon”, “07-tendermint”, or “07-ckb4ibc”.

## Bind IBC Module

Before binding the IBC Module, please follow the [MockModule](https://github.com/synapseweb3/ibc-solidity-contract/blob/master/contracts/apps/20-transfer/MockModule.sol) example to create your custom business module contract. Once you've deployed this contract in Axon, you can register its address within the `OwnableIBCHandler` contract by binding it to a channel port:

```solidity
function bindPort(string calldata portId, address moduleAddress)
```

To comply with IBC protocol regulations, a channel cannot function until it is paired with a business module through a port.

## Send ICS20 Packet

In the previous migration step, a standard ICS20 transfer module has already been bound at port `port-0` by default. Run script `scripts/send_packet.js` to send a standard custom ICS20 packet:

```bash
$ yarn send
```

This is because an IBC packet cannot be sent by directly calling the method in `OwnableIBCHandler` contract. Instead, it should be sent by calling a method in the business module, and the handler contract will be invoked subsequently.