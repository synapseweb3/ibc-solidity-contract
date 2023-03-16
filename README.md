ibc-solidity-contract is a EVM-compatible IBC implementation for AXON corsschain.

# IBC-Compatible Solidity Contracts

Implemented interfaces

- ClientCreate
- ClientUpdate
- ConnectionOpenInit
- ConnectionOpenTry
- ConnectionOpenAck
- ConnectionOpenConfirm
- ChannelOpenInit
- ChannelOpenTry
- ChannelOpenAck
- ChannelOpenConfirm
- ChannelCloseInit
- ChannelCloseConfirm
- PacketRecv
- PacketAcknowledgement

## TODO

- [ ] Split the main contract into multiple small contract (by delegation)
- [ ] Optimize commit key computation
- [ ] More testing
- [ ] Accessible control

forcerelay
- [ ] [Align conversion between clientType and clientId](https://github.com/synapseweb3/forcerelay/blob/main/crates/relayer-types/src/core/ics24_host/identifier.rs#L145)
- [ ] [No method to init a clientType from a number](https://github.com/synapseweb3/forcerelay/blob/main/crates/relayer-types/src/core/ics02_client/client_type.rs#L27).


## Contribution

1. Installs toolchain: `npm install --save-dev hardhat`
2. Compile: `npx hardhat compile`
