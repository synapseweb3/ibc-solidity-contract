ibc-solidity-contract is the EVM-compatible IBC implementation for chain based on [AXON](https://github.com/axonweb3/axon).

## Contribution

1. Installs toolchain: `npm install --save-dev truffle`
2. Compile: `npm run compile`

## Deployment on AXON

Create `.env` in project root and put axon url like

```
AXON_HTTP_RPC_URL=http://<Ip>:<Port>
```

## Deploy IBC-Solidity Handler on Axon
Run `npm run migrate --network axon` to deploy one IBC handler which have registered one [MockClient](https://github.com/synapseweb3/ibc-solidity-contract/blob/master/contracts/clients/MockClient.sol) under id `07-axon-0` and bind one [MockModule](https://github.com/synapseweb3/ibc-solidity-contract/blob/master/contracts/apps/20-transfer/MockModule.sol) under port `mock-port-0`

