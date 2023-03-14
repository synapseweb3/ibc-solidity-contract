// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./State.sol";

struct MsgClientCreate {
    ClientState clientState;
    ConsensusState consensusState;
}

struct MsgClientUpdate {
    string clientId;
    bytes headerBytes;
}

struct MsgClientMisbehaviour {
    string clientId;
    bytes header1Bytes;
    bytes header2Bytes;
}

struct MsgConnectionOpenInit {
    string clientId;
    Counterparty counterparty;
    uint64 delayPeriod;
}

struct MsgConnectionOpenTry {
    string previousConnectionId;
    Counterparty counterparty; // counterpartyConnectionIdentifier, counterpartyPrefix and counterpartyClientIdentifier
    uint64 delayPeriod;
    string clientId; // clientID of chainA
    bytes clientStateBytes; // clientState that chainA has for chainB
    Version[] counterpartyVersions; // supported versions of chain A
    bytes proofInit; // proof that chainA stored connectionEnd in state (on ConnOpenInit)
    bytes proofClient; // proof that chainA stored a light client of chainB
    bytes proofConsensus; // proof that chainA stored chainB's consensus state at consensus height
    Height proofHeight; // height at which relayer constructs proof of A storing connectionEnd in state
    Height consensusHeight; // latest height of chain B which chain A has stored in its chain B client
}

struct MsgConnectionOpenAck {
    string connectionId;
    bytes clientStateBytes; // client state for chainA on chainB
    Version version; // version that ChainB chose in ConnOpenTry
    string counterpartyConnectionID;
    bytes proofTry; // proof that connectionEnd was added to ChainB state in ConnOpenTry
    bytes proofClient; // proof of client state on chainB for chainA
    bytes proofConsensus; // proof that chainB has stored ConsensusState of chainA on its client
    Height proofHeight; // height that relayer constructed proofTry
    Height consensusHeight; // latest height of chainA that chainB has stored on its chainA client
}

struct MsgConnectionOpenConfirm {
    string connectionId;
    bytes proofAck;
    Height proofHeight;
}

/* Channel */

struct MsgChannelOpenInit {
    string portId;
    ChannelEnd channel;
}

struct MsgChannelOpenTry {
    string portId;
    string previousChannelId;
    ChannelEnd channel;
    string counterpartyVersion;
    bytes proofInit;
    Height proofHeight;
}

struct MsgChannelOpenAck {
    string portId;
    string channelId;
    string counterpartyVersion;
    string counterpartyChannelId;
    bytes proofTry;
    Height proofHeight;
}

struct MsgChannelOpenConfirm {
    string portId;
    string channelId;
    bytes proofAck;
    Height proofHeight;
}

struct MsgChannelCloseInit {
    string portId;
    string channelId;
}

struct MsgChannelCloseConfirm {
    string portId;
    string channelId;
    bytes proofInit;
    Height proofHeight;
}

/* Packet */
struct MsgPacketRecv {
    Packet packet;
    bytes proof;
    Height proofHeight;
}

struct MsgPacketAcknowledgement {
    Packet packet;
    bytes acknowledgement;
    bytes proof;
    Height proofHeight;
}

struct MsgTimeoutPacket {
    Packet packet;
    uint256 nextSequenceRecv;
    Proofs proofs;
}

struct MsgTimeoutOnClosePacket {
    Packet packet;
}
