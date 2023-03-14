// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./ILightClient.sol";
import "./types/Msg.sol";
import "./IBCStore.sol";
import "./IBCCommitment.sol";

contract IBCClient is IBCStore {
    /**
     * @dev registerClient registers a new client type into the client registry
     */
    function registerClient(ClientType clientType, ILightClient client) external {
        require(address(clientRegistry[clientType]) == address(0), "clientImpl already exists");
        clientRegistry[clientType] = address(client);
    }

    event CreateClient(string clientId, uint indexed clientType, Height height);
    /**
     * @dev createClient creates a new client state and populates it with a given consensus state
     */
    function clientCreate(MsgClientCreate calldata message) external returns (string memory clientId) {
        ClientType clientType = message.clientState.clientType;
        address clientImpl = clientRegistry[clientType];
        require(clientImpl != address(0), "unregistered client type");
        clientId = generateClientIdentifier(clientType);
        clientTypes[clientId] = clientType;
        clientImpls[clientId] = clientImpl;
        (ClientState memory clientState, ConsensusStateUpdate memory consensusStateUpdate, bool ok) = ILightClient(clientImpl)
            .clientCreate(clientId, message);
        require(ok, "failed to create client");

        // update commitments
        commitClientState(clientId, clientState);
        commitConsensusState(clientId, consensusStateUpdate);
        emit CreateClient(clientId, uint(clientType), clientState.latestHeight);
        return clientId;
    }

    event UpdateClient(string clientId, uint indexed clientType, Height consensusHeight);
    /**
     * @dev updateClient updates the consensus state and the state root from a provided header
     */
    function clientUpdate(MsgClientUpdate calldata message) external {
        string memory clientId = message.clientId;
        require(commitments[IBCCommitment.clientStateCommitmentKey(clientId)] != bytes32(0));
        // (bytes32 clientStateCommitment, ConsensusState[] memory updates, bool ok) = getClient(message.clientId)
        // .XclientUpdate(message.clientId, message.clientMessage);
        (ClientState memory clientState, ConsensusStateUpdate[] memory consensusStateUpdates, bool ok) = getClient(clientId)
            .clientUpdate(clientId, message);
        require(ok, "failed to update client");

        // update commitments
        commitClientState(clientId, clientState);

        for (uint256 i = 0; i < consensusStateUpdates.length; i++) {
            commitConsensusState(message.clientId, consensusStateUpdates[i]);
        }
        emit UpdateClient(clientId, uint(clientTypes[clientId]), clientState.latestHeight);
    }

    function commitClientState(string memory clientId, ClientState memory clientState) private {
        commitments[IBCCommitment.clientStateCommitmentKey(clientId)] = keccak256(abi.encode(clientState));
    }

    function commitConsensusState(string memory clientId, ConsensusStateUpdate memory consensusStateUpdate) private {
        commitments[
            IBCCommitment.consensusStateCommitmentKey(
                clientId,
                consensusStateUpdate.height.revisionNumber,
                consensusStateUpdate.height.revisionHeight
            )
        ] = keccak256(abi.encode(consensusStateUpdate.consensusState));
    }

    function generateClientIdentifier(ClientType clientType) private returns (string memory) {
        string memory identifier = string(abi.encode(clientType, "-", Strings.toString(nextClientSequence)));
        nextClientSequence++;
        return identifier;
    }
}
