// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./basic.sol";

struct ClientState {
    string      chain_id;
    CLIENT_TYPE client_type;
    bytes32     latest_height;
    bytes32     frozen_height;
    uint256     trusting_period;
    uint256     max_clock_drift;
    bytes       extra_payload;
}

// the key is 'client_id' + 'height'
struct ConsensusState {
    uint256 timestamp;
    bytes32 commitment_root;
    bytes   extra_payload;
}

struct ConnectionEnd {
    ConnectionId connection_id;
    STATE        state;
    string       client_id;
    ConnectionId conterparty;
    string[]     versions;
    uint256      delay_period;
}

struct ChannelEnd {
    ChannelId channel_id;
    STATE     state;
    ORDERING  odering;
    ChannelId remote;
    string[]  connection_hops;
    string    version;
}
