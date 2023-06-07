ibc-solidity-contract is the EVM-compatible IBC implementation for chain based on [AXON](https://github.com/axonweb3/axon).

## Contribution

1. Installs toolchain: `npm install --save-dev truffle`
2. Compile: `npx truffle compile --all`

## Deployment on AXON

Create `.env` in project root and put axon url like

```
AXON_RPC_URL=localhost:8000
```

Run `npx truffle migrate --network axon`
