// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./types/ibc_msg.sol";
// import "hardhat/console.sol";

interface IBCLightClient {
    function client_create(MsgClientCreate memory create) external returns(string memory);
    function client_update(MsgClientUpdate memory update) external;
    function client_misbehaviour(MsgClientMisbehaviour memory misbehaviour) external;
    function connection_open_init(MsgConnectionOpenInit memory openInit) external returns(string memory);
    function connection_open_try(MsgConnectionOpenTry memory openTry) external returns(string memory);
    function connection_open_ack(MsgConnectionOpenAck memory openAck) external;
    function connection_open_confirm(MsgConnectionOpenConfirm memory openConfirm) external;
    function channel_open_init(MsgChannelOpenInit memory openInit) external returns(string memory);
    function channel_open_try(MsgChannelOpenTry memory openTry) external returns(string memory);
    function channel_open_ack(MsgChannelOpenAck memory openAck) external;
    function channel_open_confirm(MsgChannelOpenConfirm memory openConfirm) external;
    function channel_close_init(MsgChannelCloseInit memory closeInit) external;
    function channel_close_confirm(MsgChannelCloseConfirm memory closeConfirm) external;
    function recv_packet(MsgRecvPacket memory recvPacket) external;
    function ack_packet(MsgAckPacket memory ackPacket) external;
    function timeout_packet(MsgTimeoutPacket memory timeoutPacket) external;
    function close_packet(MsgTimeoutPacket memory closePacket) external;
}

contract IBC is AccessControl {
    bytes32 public constant IBC_RELAYER = keccak256("IBC_RELAYER");

    bool _paused;
    mapping (CLIENT_TYPE => address) _lightclients;
    mapping (string => CLIENT_TYPE)  _id_client_types;

    modifier hasClient(string memory ccc_id) {
        require(
            _id_client_types[ccc_id] != CLIENT_TYPE.Unknown
                && _lightclients[_id_client_types[ccc_id]] != address(0),
            "IBC: hasClient(ccc_id) check failed"
        );
        _;
    }

    modifier whenNotPaused {
        require(!_paused, "IBC: paused");
        _;
    }

    function construct() public {
        _paused = false;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function get_light_client(string memory client_id) 
        public
        view 
        hasClient(client_id)
        returns (address)
    {
        return _lightclients[_id_client_types[client_id]];
    }

    function set_light_client(CLIENT_TYPE client_type, address light_client)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _lightclients[client_type] = light_client;
    }

    function set_pause(bool pause) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _paused = pause;
    }

    /////////////////////////////////////////////////////////
    // IBC-Compatible Events
    /////////////////////////////////////////////////////////

    event CreateClient(string client_id, uint indexed client_type, uint number);

    event UpdateClient(string client_id, uint indexed client_type, uint number);

    /////////////////////////////////////////////////////////
    // IBC-Compatible Interfaces
    /////////////////////////////////////////////////////////
    
    function client_create(MsgClientCreate memory create)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        CLIENT_TYPE client_type = create.client.client_type;
        require(_lightclients[client_type] != address(0), "IBC: client_type doesn't exist");

        string memory client_id = IBCLightClient(_lightclients[client_type]).client_create(create);
        require(_id_client_types[client_id] == CLIENT_TYPE.Unknown, "IBC: generated client_id error");
        _id_client_types[client_id] = client_type;

        emit CreateClient(client_id, uint(client_type), block.number);
    }

    function client_update(MsgClientUpdate memory update)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(update.client_id);
        IBCLightClient(lightclient).client_update(update);

        emit UpdateClient(update.client_id, uint(_id_client_types[update.client_id]), block.number);
    }

    function client_misbehaviour(MsgClientMisbehaviour memory misbehaviour)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(misbehaviour.client_id);
        IBCLightClient(lightclient).client_misbehaviour(misbehaviour);
    }

    function connection_open_init(MsgConnectionOpenInit memory openInit)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(openInit.client_id);
        string memory connection_id = IBCLightClient(lightclient).connection_open_init(openInit);
        _id_client_types[connection_id] = _id_client_types[openInit.client_id];
    }

    function connection_open_try(MsgConnectionOpenTry memory openTry)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(openTry.client_id);
        string memory connection_id = IBCLightClient(lightclient).connection_open_try(openTry);
        _id_client_types[connection_id] = _id_client_types[openTry.client_id];
    }

    function connection_open_ack(MsgConnectionOpenAck memory openAck)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(openAck.connection_id);
        IBCLightClient(lightclient).connection_open_ack(openAck);
    }

    function connection_open_confirm(MsgConnectionOpenConfirm memory openConfirm)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(openConfirm.connection_id);
        IBCLightClient(lightclient).connection_open_confirm(openConfirm);
    }

    function channel_open_init(MsgChannelOpenInit memory openInit)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        require(openInit.channel.connection_hops.length > 0, "IBC: channel has no connections");
        string memory connection_id = openInit.channel.connection_hops[0];
        address lightclient = get_light_client(connection_id);
        string memory channel_id = IBCLightClient(lightclient).channel_open_init(openInit);
        _id_client_types[channel_id] = _id_client_types[connection_id];
    }

    function channel_open_try(MsgChannelOpenTry memory openTry)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        require(openTry.channel.connection_hops.length > 0, "IBC: channel has no connections");
        string memory connection_id = openTry.channel.connection_hops[0];
        address lightclient = get_light_client(connection_id);
        string memory channel_id = IBCLightClient(lightclient).channel_open_try(openTry);
        _id_client_types[channel_id] = _id_client_types[connection_id];
    }

    function channel_open_ack(MsgChannelOpenAck memory openAck)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(openAck.channel_id.channel_id);
        IBCLightClient(lightclient).channel_open_ack(openAck);
    }

    function channel_open_confirm(MsgChannelOpenConfirm memory openConfirm)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(openConfirm.channel_id.channel_id);
        IBCLightClient(lightclient).channel_open_confirm(openConfirm);
    }

    function channel_close_init(MsgChannelCloseInit memory closeInit)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(closeInit.channel_id.channel_id);
        IBCLightClient(lightclient).channel_close_init(closeInit);
    }

    function channel_close_confirm(MsgChannelCloseConfirm memory closeConfirm)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(closeConfirm.channel_id.channel_id);
        IBCLightClient(lightclient).channel_close_confirm(closeConfirm);
    }

    function recv_packet(MsgRecvPacket memory recvPacket)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(recvPacket.packet.destination_channel_id);
        IBCLightClient(lightclient).recv_packet(recvPacket);
    }

    function ack_packet(MsgAckPacket memory ackPacket)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(ackPacket.packet.source_channel_id);
        IBCLightClient(lightclient).ack_packet(ackPacket);
    }

    function timeout_packet(MsgTimeoutPacket memory timeoutPacket)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(timeoutPacket.packet.source_channel_id);
        IBCLightClient(lightclient).timeout_packet(timeoutPacket);
    }

    function close_packet(MsgTimeoutPacket memory closePacket)
        public
        onlyRole(IBC_RELAYER)
        whenNotPaused
    {
        address lightclient = get_light_client(closePacket.packet.source_channel_id);
        IBCLightClient(lightclient).close_packet(closePacket);
    }
}
