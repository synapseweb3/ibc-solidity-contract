// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./abstract.sol";

contract CkbLightclient is Lightclient {
    mapping (string => ClientState) _client_states;
    mapping (string => mapping (bytes32 => ConsensusState)) _consensus_states;

    function construct(address ibc) public override {
        super.construct(ibc);
    }

    function client_create(MsgClientCreate memory create) public override onlyOwner returns(string memory) {
        require(create.client.client_type == CLIENT_TYPE.Ckb, "CKB: client_type must be CKB");

        string memory client_id = generate_client_id("CKB-", create.client.chain_id);
        bytes32 height = create.client.latest_height;
        require(
            string_equal(_client_states[client_id].chain_id, "")
                && _consensus_states[client_id][height].timestamp == 0,
            "CKB: client or consensus already contain create.client.client_id"
        );

        _client_states[client_id] = create.client;
        _consensus_states[client_id][height] = create.consensus;
        return client_id;
    }

    function client_update(MsgClientUpdate memory update) public override view onlyOwner {
        require(
            _client_states[update.client_id].client_type == CLIENT_TYPE.Ckb,
            "CKB: client or consensus doesn't contain update.client_id"
        );
    }

    function client_misbehaviour(MsgClientMisbehaviour memory misbehaviour) public override view onlyOwner {
        require(
            _client_states[misbehaviour.client_id].client_type == CLIENT_TYPE.Ckb,
            "CKB: client or consensus doesn't contain misbehaviour.client_id"
        );
    }

    function connection_open_init(MsgConnectionOpenInit memory) public override pure returns(string memory) { revert("CKB: not implemented"); }
    function connection_open_try(MsgConnectionOpenTry memory) public override pure returns(string memory) { revert("CKB: not implemented"); }
    function connection_open_ack(MsgConnectionOpenAck memory) public override pure { revert("CKB: not implemented"); }
    function connection_open_confirm(MsgConnectionOpenConfirm memory) public override pure { revert("CKB: not implemented"); }
    function channel_open_init(MsgChannelOpenInit memory) public override pure returns(string memory) { revert("CKB: not implemented"); }
    function channel_open_try(MsgChannelOpenTry memory) public override pure returns(string memory) { revert("CKB: not implemented"); }
    function channel_open_ack(MsgChannelOpenAck memory) public override pure { revert("CKB: not implemented"); }
    function channel_open_confirm(MsgChannelOpenConfirm memory) public override pure { revert("CKB: not implemented"); }
    function channel_close_init(MsgChannelCloseInit memory) public override pure { revert("CKB: not implemented"); }
    function channel_close_confirm(MsgChannelCloseConfirm memory) public override pure { revert("CKB: not implemented"); }
    function recv_packet(MsgRecvPacket memory) public override pure { revert("CKB: not implemented"); }
    function ack_packet(MsgAckPacket memory) public override pure { revert("CKB: not implemented"); }
    function timeout_packet(MsgTimeoutPacket memory) public override pure { revert("CKB: not implemented"); }
    function close_packet(MsgTimeoutPacket memory) public override pure { revert("CKB: not implemented"); }
}