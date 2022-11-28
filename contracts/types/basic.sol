// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

enum CLIENT_TYPE {
    Unknown,
    Tendermint,
    Ethereum,
    Axon,
    Ckb
}

enum STATE {
    Unknown,
    Init,
    OpenTry,
    Open,
    Closed
}

enum ORDERING {
    Unknown,
    Unordered,
    Ordered
}

struct ConnectionId {
    string client_id;
    string connection_id;
    bytes  commitment_prefix;
}

struct ChannelId {
    string port_id;
    string channel_id;
}

struct Proofs {
    uint256 height;
    bytes   object_proof;
    bytes   client_proof;
    bytes   consensus_proof;
    bytes   other_proof;
}

struct Packet {
    uint256 sequence;
    string  source_port_id;
    string  source_channel_id;
    string  destination_port_id;
    string  destination_channel_id;
    bytes   payload;
    bytes32 timeout_height;
    uint256 timeout_timestamp;
}
