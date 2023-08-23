// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../../proto/Client.sol";
import "../../proto/Connection.sol";
import "../02-client/ILightClient.sol";
import "../24-host/IBCStore.sol";
import "../05-port/ModuleManager.sol";
import "../24-host/IBCCommitment.sol";

abstract contract IBCQuerier is IBCStore {
    function getLatestHeight(
        string calldata clientId
    ) external view returns (Height.Data memory, bool) {
        return getClient(clientId).getLatestHeight(clientId);
    }

    function getClientState(
        string calldata clientId
    ) external view returns (bytes memory, bool) {
        return getClient(clientId).getClientState(clientId);
    }

    function getClientStates() external view returns (bytes[] memory) {
        bytes[] memory clientStates = new bytes[](clientIds.length);
        for (uint i = 0; i < clientIds.length; i++) {
            string memory clientId = clientIds[i];
            (clientStates[i], ) = getClient(clientId).getClientState(clientId);
        }
        return clientStates;
    }

    function getChannelClientState(
        string calldata portId,
        string calldata channelId
    ) external view returns (bytes memory, bool) {
        Channel.Data memory channel = channels[portId][channelId];
        string memory connectionId = channel.connectionHops[0];
        ConnectionEnd.Data memory connection = connections[connectionId];
        return
            getClient(connection.clientId).getClientState(connection.clientId);
    }

    function getConsensusState(
        string calldata clientId,
        Height.Data calldata height
    ) external view returns (bytes memory consensusState, bool) {
        return getClient(clientId).getConsensusState(clientId, height);
    }

    function getConnection(
        string calldata connectionId
    ) external view returns (ConnectionEnd.Data memory, bool) {
        ConnectionEnd.Data storage connection = connections[connectionId];
        return (
            connection,
            connection.state != ConnectionEnd.State.Uninitialized
        );
    }

    function getConnections()
        external
        view
        returns (IdentifiedConnectionEnd.Data[] memory)
    {
        IdentifiedConnectionEnd.Data[]
            memory identifiedConnectionEnds = new IdentifiedConnectionEnd.Data[](
                connectionIds.length
            );
        for (uint i = 0; i < connectionIds.length; i++) {
            string memory connectionId = connectionIds[i];
            identifiedConnectionEnds[i] = IdentifiedConnectionEnd.Data({
                connectionId: connectionId,
                connectionEnd: connections[connectionId]
            });
        }
        return identifiedConnectionEnds;
    }

    function getClientConnections(
        string calldata clientId
    ) external view returns (string[] memory) {
        return clientConnectionIds[clientId];
    }

    function getChannel(
        string calldata portId,
        string calldata channelId
    ) external view returns (Channel.Data memory, bool) {
        Channel.Data storage channel = channels[portId][channelId];
        return (channel, channel.state != Channel.State.Uninitialized);
    }

    function getChannels()
        external
        view
        returns (IdentifiedChannel.Data[] memory)
    {
        IdentifiedChannel.Data[]
            memory identifiedChannels = new IdentifiedChannel.Data[](
                nextChannelSequence
            );
        uint64 sequence = 0;
        for (uint i = 0; i < portIds.length; i++) {
            string memory portId = portIds[i];
            string[] memory channelIds = portChannelIds[portId];
            for (uint j = 0; j < channelIds.length; j++) {
                string memory channelId = channelIds[j];
                Channel.Data memory channel = channels[portId][channelId];
                identifiedChannels[sequence] = IdentifiedChannel.Data({
                    state: channel.state,
                    ordering: channel.ordering,
                    counterparty: channel.counterparty,
                    connectionHops: channel.connectionHops,
                    version: channel.version,
                    portId: portId,
                    channelId: channelId
                });
                sequence++;
            }
        }
        return identifiedChannels;
    }

    function getConnectionChannels(
        string calldata connectionId
    ) external view returns (IdentifiedChannel.Data[] memory) {
        string[] memory portIds = connectionPortIds[connectionId];
        IdentifiedChannel.Data[]
            memory identifiedChannels = new IdentifiedChannel.Data[](
                portIds.length * channelIds.length
            );
        uint64 sequence = 0;
        for (uint i = 0; i < portIds.length; i++) {
            string memory portId = portIds[i];
            string[] memory channelIds = portChannelIds[portId];
            for (uint j = 0; j < channelIds.length; j++) {
                string memory channelId = channelIds[j];
                Channel.Data memory channel = channels[portId][channelId];
                identifiedChannels[sequence] = IdentifiedChannel.Data({
                    state: channel.state,
                    ordering: channel.ordering,
                    counterparty: channel.counterparty,
                    connectionHops: channel.connectionHops,
                    version: channel.version,
                    portId: portId,
                    channelId: channelId
                });
                sequence++;
            }
        }
        return identifiedChannels;
    }

    function getConsensusHeights(
        string memory clientId
    ) external view returns (Height.Data[] memory) {
        Height.Data[] storage heights = consensusHeights[clientId];
        return heights;
    }

    function getHashedPacketCommitment(
        string calldata portId,
        string calldata channelId,
        uint64 sequence
    ) external view returns (bytes32, bool) {
        bytes32 commitment = commitments[
            keccak256(
                IBCCommitment.packetCommitmentPath(portId, channelId, sequence)
            )
        ];
        return (commitment, commitment != bytes32(0));
    }

    function getHashedPacketAcknowledgementCommitment(
        string calldata portId,
        string calldata channelId,
        uint64 sequence
    ) external view returns (bytes32, bool) {
        bytes32 commitment = commitments[
            keccak256(
                IBCCommitment.packetAcknowledgementCommitmentPath(
                    portId,
                    channelId,
                    sequence
                )
            )
        ];
        return (commitment, commitment != bytes32(0));
    }

    function getHashedPacketCommitmentSequences(
        string calldata portId,
        string calldata channelId
    ) external view returns (uint64[] memory) {
        uint64 maxSeq = nextSequenceSends[portId][channelId];
        bool[] memory allCommitmentSequences = new bool[](maxSeq);
        uint valid_count = 0;
        for (uint64 i = 0; i < maxSeq; i++) {
            (, bool ok) = this.getHashedPacketCommitment(portId, channelId, i);
            allCommitmentSequences[i] = ok;
            if (ok) {
                valid_count += 1;
            }
        }
        uint64[] memory commitmentSequences = new uint64[](valid_count);
        uint push_i = 0;
        for (uint64 i = 0; i < maxSeq; i++) {
            if (allCommitmentSequences[i]) {
                commitmentSequences[push_i++] = i;
            }
        }
        return commitmentSequences;
    }

    function hasPacketReceipt(
        string calldata portId,
        string calldata channelId,
        uint64 sequence
    ) external view returns (bool) {
        return packetReceipts[portId][channelId][sequence] == 1;
    }

    function getNextSequenceSend(
        string calldata portId,
        string calldata channelId
    ) external view returns (uint64) {
        return nextSequenceSends[portId][channelId];
    }

    function getNextSequenceRecvs(
        string calldata portId,
        string calldata channelId
    ) external view returns (uint64) {
        return nextSequenceRecvs[portId][channelId];
    }

    function getExpectedTimePerBlock() external view returns (uint64) {
        return expectedTimePerBlock;
    }
}
