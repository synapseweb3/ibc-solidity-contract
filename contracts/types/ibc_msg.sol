// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ibc_state.sol";

struct MsgClientCreate {
    ClientState    client;
    ConsensusState consensus;
}

struct MsgClientUpdate {
    string client_id;
    bytes  header_bytes;
}

struct MsgClientMisbehaviour {
    string client_id;
    bytes  header1_bytes;
    bytes  header2_bytes;
}

struct MsgConnectionOpenInit {
    string       client_id;
    ConnectionId counterparty;
    string       version;
    uint256      delay_duration;
}

struct MsgConnectionOpenTry {
    string       previous_connection_id;
    string       client_id;
    ClientState  client_state;
    ConnectionId counterparty;
    string[]     counterparty_versions;
    Proofs       proofs;
    uint256      delay_period;
}

struct MsgConnectionOpenAck {
    string      connection_id;
    string      counterparty_connection_id;
    ClientState client_state;
    Proofs      proofs;
    string      version;
}

struct MsgConnectionOpenConfirm {
    string connection_id;
    Proofs proofs;
}

struct MsgChannelOpenInit {
    string     port_id;
    ChannelEnd channel;
}

struct MsgChannelOpenTry {
    string     port_id;
    ChannelId  previous_channel_id;
    ChannelEnd channel;
    string     counterparty_version;
    Proofs     proofs;
}

struct MsgChannelOpenAck {
    string    port_id;
    ChannelId channel_id;
    ChannelId counterparty_channel_id;
    string    counterparty_version;
    Proofs    proofs;
}

struct MsgChannelOpenConfirm {
    string    port_id;
    ChannelId channel_id;
    Proofs    proofs;
}

struct MsgChannelCloseInit {
    string    port_id;
    ChannelId channel_id;
}

struct MsgChannelCloseConfirm {
    string    port_id;
    ChannelId channel_id;
    Proofs    proofs;
}

struct MsgRecvPacket {
    Packet packet;
    Proofs proofs;
}

struct MsgAckPacket {
    Packet packet;
    bytes  acknowledgement;
    Proofs proofs;
}

struct MsgTimeoutPacket {
    Packet  packet;
    uint256 next_sequence_recv;
    Proofs  proofs;
}
