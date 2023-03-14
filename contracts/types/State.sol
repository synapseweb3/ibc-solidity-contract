// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

enum ClientType {
    UNKNOWN, // UNKNOWN should be the first element
    TENDERMINT,
    ETHEREUM,
    CKB,
    AXON
}

enum ConnectionState {
    UNKNOWN,
    INIT,
    TRYOPEN,
    OPEN
}

struct ConnectionId {
    string clientId;
    string connectionId;
    bytes commitmentPrefix;
}

struct ChannelId {
    string portId;
    string channelId;
}

struct Height {
    uint64 revisionNumber;
    uint64 revisionHeight;
}

struct Proofs {
    uint64 height;
    bytes objectProof;
    bytes clientProof;
    bytes consensusProof;
    bytes otherProof;
}

struct Packet {
    uint64 sequence;
    string sourcePort;
    string sourceChannel;
    string destinationPort;
    string destinationChannel;
    bytes data;
    Height timeoutHeight;
    uint64 timeoutTimestamp;
}

struct ClientState {
    string chainId;
    ClientType clientType;
    Height latestHeight;
    Height frozenHeight;
    uint256 trustingPeriod;
    uint256 maxClockDrift;
    bytes extraPayload;
}

// the key is 'clientId' + 'height'
struct ConsensusState {
    uint256 timestamp;
    bytes32 commitmentRoot;
    bytes extraPayload;
}

struct Version {
    string identifier;
    string[] features;
}

struct Counterparty {
    string clientId;
    string connectionId;
    bytes prefix;
}

struct ConnectionEnd {
    string clientId;
    Version[] versions;
    ConnectionState state;
    Counterparty counterparty;
    uint64 delayPeriod;
}

enum ChannelState {
    UNKNOWN,
    INIT,
    TRYOPEN,
    OPEN,
    CLOSED
}

enum Order {
    UNKNOWN,
    UNORDERED,
    ORDERED
}

struct ChannelCounterparty {
    string portId;
    string channelId;
}

struct ChannelEnd {
    ChannelState state;
    Order ordering;
    ChannelCounterparty counterparty;
    string[] connectionHops;
    string version;
}
