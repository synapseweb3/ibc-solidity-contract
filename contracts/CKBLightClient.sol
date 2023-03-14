// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.9;

// import "./ILightClient.sol";

// abstract contract CKBLightClient is ILightClient {
//     mapping(string => ClientState) internal clientStates;
//     mapping(string => mapping(uint64 => ConsensusState)) internal consensusStates;

//     // TODO: accessible control

//     function hasClient(string memory clientId) public view returns (bool) {
//         return clientStates[clientId].clientType != ClientType.UNKNOWN;
//     }

//     function updateClient(
//         string memory clientId,
//         ClientState memory clientState,
//         ConsensusState memory consensusState
//     ) private {
//         clientStates[clientId] = clientState;
//         consensusStates[clientId][clientState.latestHeight] = consensusState;
//     }

//     function XclientCreate(
//         string memory clientId,
//         MsgClientCreate memory message
//     ) external override returns (ClientState memory clientState, ConsensusState memory consensusState, bool ok) {
//         clientId = generateClientIdentifier();
//         require(clientStates[clientId].clientType == ClientType.UNKNOWN, "client already exists");


//         // TODO: implement logic

//         updateClient(clientId, clientState, consensusState);

//         emit CreateClient(clientId, uint(clientType));
//         return clientId;
//     }
// }
