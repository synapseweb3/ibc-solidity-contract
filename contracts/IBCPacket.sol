// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./types/Msg.sol";
import "./types/State.sol";
import "./types/IBCHeight.sol";
import "./IBCStore.sol";
import "./IBCCommitment.sol";

/**
 * @dev IBCPacket is a contract that implements [ICS-4](https://github.com/cosmos/ibc/tree/main/spec/core/ics-004-channel-and-packet-semantics).
 */
contract IBCPacket is IBCStore {
    using IBCHeight for Height;

    /* Packet handlers */

    event SendPacket(Packet packet);

    /**
     * @dev sendPacket is called by a module in order to send an IBC packet on a channel.
     * The packet sequence generated for the packet to be sent is returned. An error
     * is returned if one occurs.
     */
    function sendPacket(Packet calldata packet) external {
        uint64 latestTimestamp;

        ChannelEnd storage channel = channels[packet.sourcePort][packet.sourceChannel];

        require(channel.state == ChannelState.OPEN, "ChannelEnd state must be OPEN");
        require(
            hashString(packet.destinationPort) == hashString(channel.counterparty.portId),
            "packet destination port doesn't match the counterparty's port"
        );
        require(
            hashString(packet.destinationChannel) == hashString(channel.counterparty.channelId),
            "packet destination ChannelEnd doesn't match the counterparty's channel"
        );
        ConnectionEnd storage connection = connections[channel.connectionHops[0]];
        ILightClient client = ILightClient(clientImpls[connection.clientId]);
        (Height memory latestHeight, bool found) = client.getLatestHeight(connection.clientId);
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
        commitments[
            IBCCommitment.packetCommitmentKey(packet.sourcePort, packet.sourceChannel, packet.sequence)
        ] = keccak256(
            abi.encode(
                sha256(
                    abi.encode(
                        packet.timeoutTimestamp,
                        packet.timeoutHeight.revisionNumber,
                        packet.timeoutHeight.revisionHeight,
                        sha256(packet.data)
                    )
                )
            )
        );
        emit SendPacket(packet);
    }

    event RecvPacket(Packet packet);

    /**
     * @dev recvPacket is called by a module in order to receive & process an IBC packet
     * sent on the corresponding ChannelEnd end on the counterparty chain.
     */
    function recvPacket(MsgPacketRecv calldata message) external {
        ChannelEnd storage channel = channels[message.packet.destinationPort][message.packet.destinationChannel];
        require(channel.state == ChannelState.OPEN, "ChannelEnd state must be OPEN");

        // TODO
        // Authenticate capability to ensure caller has authority to receive packet on this channel

        require(
            hashString(message.packet.sourcePort) == hashString(channel.counterparty.portId),
            "packet source port doesn't match the counterparty's port"
        );
        require(
            hashString(message.packet.sourceChannel) == hashString(channel.counterparty.channelId),
            "packet source ChannelEnd doesn't match the counterparty's channel"
        );

        ConnectionEnd storage connection = connections[channel.connectionHops[0]];
        require(connection.state == ConnectionState.OPEN, "connection state is not OPEN");

        require(
            message.packet.timeoutHeight.revisionHeight == 0 ||
                block.number < message.packet.timeoutHeight.revisionHeight,
            "block height >= packet timeout height"
        );
        require(
            message.packet.timeoutTimestamp == 0 || block.timestamp < message.packet.timeoutTimestamp,
            "block timestamp >= packet timeout timestamp"
        );

        require(
            verifyPacketCommitment(
                connection,
                message.proofHeight,
                message.proof,
                IBCCommitment.packetCommitmentPath(
                    message.packet.sourcePort,
                    message.packet.sourceChannel,
                    message.packet.sequence
                ),
                sha256(
                    abi.encode(
                        message.packet.timeoutTimestamp,
                        message.packet.timeoutHeight.revisionNumber,
                        message.packet.timeoutHeight.revisionHeight,
                        sha256(message.packet.data)
                    )
                )
            ),
            "failed to verify packet commitment"
        );

        if (channel.ordering == Order.UNORDERED) {
            require(
                packetReceipts[message.packet.destinationPort][message.packet.destinationChannel][
                    message.packet.sequence
                ] == 0,
                "packet sequence already has been received"
            );
            packetReceipts[message.packet.destinationPort][message.packet.destinationChannel][
                message.packet.sequence
            ] = 1;
        } else if (channel.ordering == Order.ORDERED) {
            require(
                nextSequenceRecvs[message.packet.destinationPort][message.packet.destinationChannel] ==
                    message.packet.sequence,
                "packet sequence != next receive sequence"
            );
            nextSequenceRecvs[message.packet.destinationPort][message.packet.destinationChannel]++;
        } else {
            revert("unknown ordering type");
        }
        emit RecvPacket(message.packet);
    }

    event WriteAcknowledgement(Packet packet, bytes ack);

    /**
     * @dev writeAcknowledgement writes the packet execution acknowledgement to the state,
     * which will be verified by the counterparty chain using AcknowledgePacket.
     */
    function writeAcknowledgement(Packet calldata packet, bytes calldata acknowledgement) external {
        require(acknowledgement.length > 0, "acknowledgement cannot be empty");
        string memory destinationPort = packet.destinationPort;
        string memory destinationChannel = packet.destinationChannel;
        uint64 sequence = packet.sequence;
        ChannelEnd storage channel = channels[destinationPort][destinationChannel];
        require(channel.state == ChannelState.OPEN, "ChannelEnd state must be OPEN");

        bytes32 ackCommitmentKey = IBCCommitment.packetAcknowledgementCommitmentKey(
            destinationPort,
            destinationChannel,
            sequence
        );
        bytes32 ackCommitment = commitments[ackCommitmentKey];
        require(ackCommitment == bytes32(0), "acknowledgement for packet already exists");
        commitments[ackCommitmentKey] = keccak256(abi.encode(sha256(acknowledgement)));
        emit WriteAcknowledgement(packet, acknowledgement);
    }

    event AcknowledgePacket(Packet packet);

    /**
     * @dev AcknowledgePacket is called by a module to process the acknowledgement of a
     * packet previously sent by the calling module on a ChannelEnd to a counterparty
     * module on the counterparty chain. Its intended usage is within the ante
     * handler. AcknowledgePacket will clean up the packet commitment,
     * which is no longer necessary since the packet has been received and acted upon.
     * It will also increment NextSequenceAck in case of ORDERED channels.
     */
    function acknowledgePacket(MsgPacketAcknowledgement calldata message) external {
        ChannelEnd storage channel = channels[message.packet.sourcePort][message.packet.sourceChannel];
        require(channel.state == ChannelState.OPEN, "ChannelEnd state must be OPEN");

        require(
            hashString(message.packet.destinationPort) == hashString(channel.counterparty.portId),
            "packet destination port doesn't match the counterparty's port"
        );
        require(
            hashString(message.packet.destinationChannel) == hashString(channel.counterparty.channelId),
            "packet destination ChannelEnd doesn't match the counterparty's channel"
        );

        ConnectionEnd storage connection = connections[channel.connectionHops[0]];
        require(connection.state == ConnectionState.OPEN, "connection state is not OPEN");

        bytes32 packetCommitmentKey = IBCCommitment.packetCommitmentKey(
            message.packet.sourcePort,
            message.packet.sourceChannel,
            message.packet.sequence
        );
        bytes32 packetCommitment = commitments[packetCommitmentKey];
        require(packetCommitment != bytes32(0), "packet commitment not found");
        require(
            packetCommitment ==
                keccak256(
                    abi.encode(
                        sha256(
                            abi.encode(
                                message.packet.timeoutTimestamp,
                                message.packet.timeoutHeight.revisionNumber,
                                message.packet.timeoutHeight.revisionHeight,
                                sha256(message.packet.data)
                            )
                        )
                    )
                ),
            "commitment bytes are not equal"
        );

        require(
            verifyPacketAcknowledgement(
                connection,
                message.proofHeight,
                message.proof,
                IBCCommitment.packetAcknowledgementCommitmentPath(
                    message.packet.destinationPort,
                    message.packet.destinationChannel,
                    message.packet.sequence
                ),
                sha256(message.acknowledgement)
            ),
            "failed to verify packet acknowledgement commitment"
        );

        if (channel.ordering == Order.ORDERED) {
            require(
                message.packet.sequence == nextSequenceAcks[message.packet.sourcePort][message.packet.sourceChannel],
                "packet sequence != next ack sequence"
            );
            nextSequenceAcks[message.packet.sourcePort][message.packet.sourceChannel]++;
        }

        delete commitments[packetCommitmentKey];
        emit AcknowledgePacket(message.packet);
    }

    function hashString(string memory s) private pure returns (bytes32) {
        return keccak256(abi.encode(s));
    }

    /* Verification functions */

    function verifyPacketCommitment(
        ConnectionEnd storage connection,
        Height calldata height,
        bytes calldata proof,
        bytes memory path,
        bytes32 commitmentBytes
    ) private returns (bool) {
        return
            getClient(connection.clientId).verifyMembership(
                connection.clientId,
                height,
                connection.delayPeriod,
                calcBlockDelay(connection.delayPeriod),
                proof,
                connection.counterparty.prefix,
                path,
                abi.encode(commitmentBytes)
            );
    }

    function verifyPacketAcknowledgement(
        ConnectionEnd storage connection,
        Height calldata height,
        bytes calldata proof,
        bytes memory path,
        bytes32 acknowledgementCommitmentBytes
    ) private returns (bool) {
        return
            getClient(connection.clientId).verifyMembership(
                connection.clientId,
                height,
                connection.delayPeriod,
                calcBlockDelay(connection.delayPeriod),
                proof,
                connection.counterparty.prefix,
                path,
                abi.encode(acknowledgementCommitmentBytes)
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
