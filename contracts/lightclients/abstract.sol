// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../types/ibc_msg.sol";

abstract contract Lightclient {
    address _owner;
    uint256 _client_counter;

    modifier onlyOwner {
        require(msg.sender == _owner, "LIGHTCLIENT: caller is not ibc relayer");
        _;
    }

    function construct(address ibc) virtual public {
        _owner = ibc;
        _client_counter = 0;
    }

    function string_equal(string storage a, string memory b) internal pure returns(bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function generate_client_id(string memory prefix, string memory chain_id) internal returns(string memory) {
        return string.concat(prefix, chain_id, "-", Strings.toString(++_client_counter));
    }

    /////////////////////////////////////////////////////////
    // IBC-Compatible Virtual Interfaces
    /////////////////////////////////////////////////////////

    function client_create(MsgClientCreate memory create) virtual public returns(string memory);
    function client_update(MsgClientUpdate memory update) virtual public;
    function client_misbehaviour(MsgClientMisbehaviour memory misbehaviour) virtual public;
    function connection_open_init(MsgConnectionOpenInit memory openInit) virtual public returns(string memory);
    function connection_open_try(MsgConnectionOpenTry memory openTry) virtual public returns(string memory);
    function connection_open_ack(MsgConnectionOpenAck memory openAck) virtual public;
    function connection_open_confirm(MsgConnectionOpenConfirm memory openConfirm) virtual public;
    function channel_open_init(MsgChannelOpenInit memory openInit) virtual public returns(string memory);
    function channel_open_try(MsgChannelOpenTry memory openTry) virtual public returns(string memory);
    function channel_open_ack(MsgChannelOpenAck memory openAck) virtual public;
    function channel_open_confirm(MsgChannelOpenConfirm memory openConfirm) virtual public;
    function channel_close_init(MsgChannelCloseInit memory closeInit) virtual public;
    function channel_close_confirm(MsgChannelCloseConfirm memory closeConfirm) virtual public;
    function recv_packet(MsgRecvPacket memory recvPacket) virtual public;
    function ack_packet(MsgAckPacket memory ackPacket) virtual public;
    function timeout_packet(MsgTimeoutPacket memory timeoutPacket) virtual public;
    function close_packet(MsgTimeoutPacket memory closePacket) virtual public;
}
