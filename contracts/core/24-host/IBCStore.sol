// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../../proto/Client.sol";
import "../../proto/Connection.sol";
import "../../proto/Channel.sol";
import "../../proto/CellEmitter.sol";
import "../02-client/ILightClient.sol";

abstract contract IBCStore {
    // Commitments
    // keccak256(IBC-compatible-store-path) => keccak256(IBC-compatible-commitment)
    mapping(bytes32 => bytes32) public commitments;

    // Store
    string[] public clientIds;
    string[] public connectionIds;
    mapping(string => string[]) public clientConnectionIds; // clientId => connectionId[]
    string[] public portIds;
    string[] public channelIds;
    mapping(string => string[]) public portChannelIds; // portId => channelId[]
    mapping(string => string[]) public connectionChannelIds; // connectionId => channelId[]

    mapping(string => address) public clientRegistry; // clientType => clientImpl
    mapping(string => string) public clientTypes; // clientID => clientType
    mapping(string => address) public clientImpls; // clientID => clientImpl
    mapping(string => ConnectionEnd.Data) public connections;
    mapping(string => mapping(string => Channel.Data)) public channels;
    mapping(string => mapping(string => uint64)) public nextSequenceSends;
    mapping(string => mapping(string => uint64)) public nextSequenceRecvs;
    mapping(string => mapping(string => uint64)) public nextSequenceAcks;
    mapping(string => mapping(string => mapping(uint64 => uint8))) public packetReceipts;
    mapping(bytes => address[]) public capabilities;

    mapping(string => Height.Data[]) public consensusHeights; // clientId => heights
    // Host parameters
    uint64 public expectedTimePerBlock;

    // Sequences for identifier
    uint64 public nextClientSequence;
    uint64 public nextConnectionSequence;
    uint64 public nextChannelSequence;

    CellEmitter.Filter[] emitterFilters;
    // Storage accessors

    function getClient(string memory clientId) internal view returns (ILightClient) {
        address clientImpl = clientImpls[clientId];
        require(clientImpl != address(0));
        return ILightClient(clientImpl);
    }
}
