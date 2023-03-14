// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./types/State.sol";
// import "./ILightClient.sol";
import "./ILightClient.sol";

abstract contract IBCStore {
    mapping(string => ClientState) internal clientStates;
    mapping(string => mapping(uint64 => ConsensusState)) internal consensusStates;

    // Commitments
    // keccak256(IBC-compatible-store-path) => keccak256(IBC-compatible-commitment)
    mapping(bytes32 => bytes32) internal commitments;

    // Store
    mapping(ClientType => address) internal clientRegistry; // clientType => clientImpl
    mapping(string => ClientType) internal clientTypes; // clientID => clientType
    mapping(string => address) internal clientImpls; // clientID => clientImpl
    mapping(string => ConnectionEnd) internal connections;
    mapping(string => mapping(string => ChannelEnd)) internal channels;
    mapping(string => mapping(string => uint64)) internal nextSequenceSends;
    mapping(string => mapping(string => uint64)) internal nextSequenceRecvs;
    mapping(string => mapping(string => uint64)) internal nextSequenceAcks;
    mapping(string => mapping(string => mapping(uint64 => uint8))) internal packetReceipts;

    // Host parameters
    uint64 internal expectedTimePerBlock;

    // Sequences for identifier
    uint64 internal nextClientSequence;
    uint64 internal nextConnectionSequence;
    uint64 internal nextChannelSequence;

    // Storage accessors
    function getClient(string memory clientId) internal view returns (ILightClient) {
        address clientImpl = clientImpls[clientId];
        require(clientImpl != address(0));
        return ILightClient(clientImpl);
    }
}
