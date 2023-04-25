// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../../proto/Channel.sol";
import "../25-handler/IBCMsgs.sol";
import "../02-client/IBCHeight.sol";
import "../24-host/IBCStore.sol";
import "../24-host/IBCCommitment.sol";
import "../04-channel/IIBCChannel.sol";

/**
 * @dev IBCPacket is a contract that implements [ICS-4](https://github.com/cosmos/ibc/tree/main/spec/core/ics-004-channel-and-packet-semantics).
 */
contract IBCPacket is IBCStore, IIBCPacket {
    using IBCHeight for Height.Data;

    /* Packet handlers */

    /**
     * @dev sendPacket is called by a module in order to send an IBC packet on a channel.
     * The packet sequence generated for the packet to be sent is returned. An error
     * is returned if one occurs.
     */
    function sendPacket(Packet.Data calldata packet) external {
        uint64 latestTimestamp;

        Channel.Data storage channel = channels[packet.sourcePort][packet.sourceChannel];
        require(channel.state == Channel.State.Open, "channel state must be OPEN");
        require(
            hashString(packet.destinationPort) == hashString(channel.counterparty.portId),
            "packet destination port doesn't match the counterparty's port"
        );
        require(
            hashString(packet.destinationChannel) == hashString(channel.counterparty.channelId),
            "packet destination channel doesn't match the counterparty's channel"
        );
        ConnectionEnd.Data storage connection = connections[channel.connectionHops[0]];
        ILightClient client = ILightClient(clientImpls[connection.clientId]);
        (Height.Data memory latestHeight, bool found) = client.getLatestHeight(connection.clientId);
        require(
            packet.timeoutHeight.isZero() || latestHeight.lt(packet.timeoutHeight),
            "receiving chain block height >= packet timeout height"
        );
        (latestTimestamp, found) = client.getTimestampAtHeight(connection.clientId, latestHeight);
        require(found, "consensusState not found");
        require(
            packet.timeoutTimestamp == 0 || latestTimestamp < packet.timeoutTimestamp,
            "receiving chain block timestamp >= packet timeout timestamp"
        );

        require(
            packet.sequence == nextSequenceSends[packet.sourcePort][packet.sourceChannel],
            "packet sequence != next send sequence"
        );

        nextSequenceSends[packet.sourcePort][packet.sourceChannel]++;
        commitments[IBCCommitment.packetCommitmentKey(packet.sourcePort, packet.sourceChannel, packet.sequence)] =
        keccak256(
            abi.encodePacked(
                sha256(
                    abi.encodePacked(
                        packet.timeoutTimestamp,
                        packet.timeoutHeight.revisionNumber,
                        packet.timeoutHeight.revisionHeight,
                        sha256(packet.data)
                    )
                )
            )
        );
    }

    /**
     * @dev recvPacket is called by a module in order to receive & process an IBC packet
     * sent on the corresponding channel end on the counterparty chain.
     */
    function recvPacket(IBCMsgs.MsgPacketRecv calldata msg_) external {
        Channel.Data storage channel = channels[msg_.packet.destinationPort][msg_.packet.destinationChannel];
        require(channel.state == Channel.State.Open, "channel state must be OPEN");

        // TODO
        // Authenticate capability to ensure caller has authority to receive packet on this channel

        require(
            hashString(msg_.packet.sourcePort) == hashString(channel.counterparty.portId),
            "packet source port doesn't match the counterparty's port"
        );
        require(
            hashString(msg_.packet.sourceChannel) == hashString(channel.counterparty.channelId),
            "packet source channel doesn't match the counterparty's channel"
        );

        ConnectionEnd.Data storage connection = connections[channel.connectionHops[0]];
        require(connection.state == ConnectionEnd.State.Open, "connection state is not OPEN");

        require(
            msg_.packet.timeoutHeight.revisionHeight == 0 || block.number < msg_.packet.timeoutHeight.revisionHeight,
            "block height >= packet timeout height"
        );
        require(
            msg_.packet.timeoutTimestamp == 0 || block.timestamp < msg_.packet.timeoutTimestamp,
            "block timestamp >= packet timeout timestamp"
        );

        require(
            verifyPacketCommitment(
                connection,
                msg_.proofHeight,
                msg_.proof,
                IBCCommitment.packetCommitmentPath(
                    msg_.packet.sourcePort, msg_.packet.sourceChannel, msg_.packet.sequence
                ),
                sha256(
                    abi.encodePacked(
                        msg_.packet.timeoutTimestamp,
                        msg_.packet.timeoutHeight.revisionNumber,
                        msg_.packet.timeoutHeight.revisionHeight,
                        sha256(msg_.packet.data)
                    )
                )
            ),
            "failed to verify packet commitment"
        );

        if (channel.ordering == Channel.Order.Unordered) {
            require(
                packetReceipts[msg_.packet.destinationPort][msg_.packet.destinationChannel][msg_.packet.sequence] == 0,
                "packet sequence already has been received"
            );
            packetReceipts[msg_.packet.destinationPort][msg_.packet.destinationChannel][msg_.packet.sequence] = 1;
        } else if (channel.ordering == Channel.Order.Ordered) {
            require(
                nextSequenceRecvs[msg_.packet.destinationPort][msg_.packet.destinationChannel] == msg_.packet.sequence,
                "packet sequence != next receive sequence"
            );
            nextSequenceRecvs[msg_.packet.destinationPort][msg_.packet.destinationChannel]++;
        } else {
            revert("unknown ordering type");
        }
    }

    /**
     * @dev writeAcknowledgement writes the packet execution acknowledgement to the state,
     * which will be verified by the counterparty chain using AcknowledgePacket.
     */
    function writeAcknowledgement(
        string calldata destinationPortId,
        string calldata destinationChannel,
        uint64 sequence,
        bytes calldata acknowledgement
    ) external {
        require(acknowledgement.length > 0, "acknowledgement cannot be empty");

        Channel.Data storage channel = channels[destinationPortId][destinationChannel];
        require(channel.state == Channel.State.Open, "channel state must be OPEN");

        bytes32 ackCommitmentKey =
            IBCCommitment.packetAcknowledgementCommitmentKey(destinationPortId, destinationChannel, sequence);
        bytes32 ackCommitment = commitments[ackCommitmentKey];
        require(ackCommitment == bytes32(0), "acknowledgement for packet already exists");
        commitments[ackCommitmentKey] = keccak256(abi.encodePacked(sha256(acknowledgement)));
    }

    /**
     * @dev AcknowledgePacket is called by a module to process the acknowledgement of a
     * packet previously sent by the calling module on a channel to a counterparty
     * module on the counterparty chain. Its intended usage is within the ante
     * handler. AcknowledgePacket will clean up the packet commitment,
     * which is no longer necessary since the packet has been received and acted upon.
     * It will also increment NextSequenceAck in case of ORDERED channels.
     */
    function acknowledgePacket(IBCMsgs.MsgPacketAcknowledgement calldata msg_) external {
        Channel.Data storage channel = channels[msg_.packet.sourcePort][msg_.packet.sourceChannel];
        require(channel.state == Channel.State.Open, "channel state must be OPEN");

        require(
            hashString(msg_.packet.destinationPort) == hashString(channel.counterparty.portId),
            "packet destination port doesn't match the counterparty's port"
        );
        require(
            hashString(msg_.packet.destinationChannel) == hashString(channel.counterparty.channelId),
            "packet destination channel doesn't match the counterparty's channel"
        );

        ConnectionEnd.Data storage connection = connections[channel.connectionHops[0]];
        require(connection.state == ConnectionEnd.State.Open, "connection state is not OPEN");

        bytes32 packetCommitmentKey =
            IBCCommitment.packetCommitmentKey(msg_.packet.sourcePort, msg_.packet.sourceChannel, msg_.packet.sequence);
        bytes32 packetCommitment = commitments[packetCommitmentKey];
        require(packetCommitment != bytes32(0), "packet commitment not found");
        require(
            packetCommitment
                == keccak256(
                    abi.encodePacked(
                        sha256(
                            abi.encodePacked(
                                msg_.packet.timeoutTimestamp,
                                msg_.packet.timeoutHeight.revisionNumber,
                                msg_.packet.timeoutHeight.revisionHeight,
                                sha256(msg_.packet.data)
                            )
                        )
                    )
                ),
            "commitment bytes are not equal"
        );

        require(
            verifyPacketAcknowledgement(
                connection,
                msg_.proofHeight,
                msg_.proof,
                IBCCommitment.packetAcknowledgementCommitmentPath(
                    msg_.packet.destinationPort, msg_.packet.destinationChannel, msg_.packet.sequence
                ),
                sha256(msg_.acknowledgement)
            ),
            "failed to verify packet acknowledgement commitment"
        );

        if (channel.ordering == Channel.Order.Ordered) {
            require(
                msg_.packet.sequence == nextSequenceAcks[msg_.packet.sourcePort][msg_.packet.sourceChannel],
                "packet sequence != next ack sequence"
            );
            nextSequenceAcks[msg_.packet.sourcePort][msg_.packet.sourceChannel]++;
        }

        delete commitments[packetCommitmentKey];
    }

    function hashString(string memory s) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(s));
    }

    /* Verification functions */

    function verifyPacketCommitment(
        ConnectionEnd.Data storage connection,
        Height.Data calldata height,
        bytes calldata proof,
        bytes memory path,
        bytes32 commitmentBytes
    ) private returns (bool) {
        return getClient(connection.clientId).verifyMembership(
            connection.clientId,
            height,
            connection.delayPeriod,
            calcBlockDelay(connection.delayPeriod),
            proof,
            connection.counterparty.prefix.keyPrefix,
            path,
            abi.encodePacked(commitmentBytes)
        );
    }

    function verifyPacketAcknowledgement(
        ConnectionEnd.Data storage connection,
        Height.Data calldata height,
        bytes calldata proof,
        bytes memory path,
        bytes32 acknowledgementCommitmentBytes
    ) private returns (bool) {
        return getClient(connection.clientId).verifyMembership(
            connection.clientId,
            height,
            connection.delayPeriod,
            calcBlockDelay(connection.delayPeriod),
            proof,
            connection.counterparty.prefix.keyPrefix,
            path,
            abi.encodePacked(acknowledgementCommitmentBytes)
        );
    }

    /* Internal functions */

    function calcBlockDelay(uint64 timeDelay) private view returns (uint64) {
        uint64 blockDelay = 0;
        if (expectedTimePerBlock != 0) {
            blockDelay = (timeDelay + expectedTimePerBlock - 1) / expectedTimePerBlock;
        }
        return blockDelay;
    }
}
