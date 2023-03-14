// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./types/Msg.sol";
import "./types/State.sol";
import "./types/IBCHeight.sol";
import "./IBCStore.sol";
import "./IBCCommitment.sol";

/**
 * @dev IBCChannelHandshake is a contract that implements [ICS-4](https://github.com/cosmos/ibc/tree/main/spec/core/ics-004-channel-and-packet-semantics).
 */
contract IBCChannel is IBCStore {
    using IBCHeight for Height;

    event ChannelOpenInit(
        string portId,
        string channelId,
        string connectionId,
        string counterpartyPortId,
        string counterpartyChannelId
    );

    /**
     * @dev channelOpenInit is called by a module to initiate a channel opening handshake with a module on another chain.
     */
    function channelOpenInit(MsgChannelOpenInit calldata message) external returns (string memory) {
        require(message.channel.connectionHops.length == 1, "connectionHops length must be 1");
        ConnectionEnd storage connection = connections[message.channel.connectionHops[0]];
        require(
            connection.versions.length == 1,
            "single version must be negotiated on connection before opening channel"
        );
        require(message.channel.state == ChannelState.INIT, "channel state must STATE_INIT");

        // TODO verifySupportedFeature

        // TODO authenticates a port binding

        string memory channelId = generateChannelIdentifier();
        channels[message.portId][channelId] = message.channel;
        nextSequenceSends[message.portId][channelId] = 1;
        nextSequenceRecvs[message.portId][channelId] = 1;
        nextSequenceAcks[message.portId][channelId] = 1;
        updateChannelCommitment(message.portId, channelId);

        emit ChannelOpenInit(
            message.portId,
            channelId,
            message.channel.connectionHops[0],
            message.channel.counterparty.portId,
            message.channel.counterparty.channelId
        );
        return channelId;
    }

    event ChannelOpenTry(
        string portId,
        string channelId,
        string connectionId,
        string counterpartyPortId,
        string counterpartyChannelId
    );

    /**
     * @dev channelOpenTry is called by a module to accept the first step of a channel opening handshake initiated by a module on another chain.
     */
    function channelOpenTry(MsgChannelOpenTry calldata message) external returns (string memory) {
        require(message.channel.connectionHops.length == 1, "connectionHops length must be 1");
        ConnectionEnd storage connection = connections[message.channel.connectionHops[0]];
        require(
            connection.versions.length == 1,
            "single version must be negotiated on connection before opening channel"
        );
        require(message.channel.state == ChannelState.TRYOPEN, "channel state must be STATE_TRYOPEN");
        require(message.channel.connectionHops.length == 1);

        // TODO verifySupportedFeature

        // TODO authenticates a port binding

        ChannelCounterparty memory expectedCounterparty = ChannelCounterparty({portId: message.portId, channelId: ""});
        ChannelEnd memory expectedChannel = ChannelEnd({
            state: ChannelState.INIT,
            ordering: message.channel.ordering,
            counterparty: expectedCounterparty,
            connectionHops: getCounterpartyHops(message.channel.connectionHops[0]),
            version: message.counterpartyVersion
        });
        require(
            verifyChannelState(
                connection,
                message.proofHeight,
                message.proofInit,
                message.channel.counterparty.portId,
                message.channel.counterparty.channelId,
                abi.encode(expectedChannel)
            ),
            "failed to verify channel state"
        );

        string memory channelId = generateChannelIdentifier();
        channels[message.portId][channelId] = message.channel;
        nextSequenceSends[message.portId][channelId] = 1;
        nextSequenceRecvs[message.portId][channelId] = 1;
        nextSequenceAcks[message.portId][channelId] = 1;
        updateChannelCommitment(message.portId, channelId);

        emit ChannelOpenTry(
            message.portId,
            channelId,
            message.channel.connectionHops[0],
            message.channel.counterparty.portId,
            message.channel.counterparty.channelId
        );
        return channelId;
    }

    event ChannelOpenAck(
        string portId,
        string channelId,
        string connectionId,
        string counterpartyPortId,
        string counterpartyChannelId
    );

    /**
     * @dev channelOpenAck is called by the handshake-originating module to acknowledge the acceptance of the initial request by the counterparty module on the other chain.
     */
    function channelOpenAck(MsgChannelOpenAck calldata message) external {
        ChannelEnd storage channel = channels[message.portId][message.channelId];
        require(channel.state == ChannelState.INIT || channel.state == ChannelState.TRYOPEN, "invalid channel state");

        // TODO authenticates a port binding

        ConnectionEnd storage connection = connections[channel.connectionHops[0]];
        require(connection.state == ConnectionState.OPEN, "connection state is not OPEN");
        require(channel.connectionHops.length == 1);

        ChannelCounterparty memory expectedCounterparty = ChannelCounterparty({
            portId: message.portId,
            channelId: message.channelId
        });
        ChannelEnd memory expectedChannel = ChannelEnd({
            state: ChannelState.TRYOPEN,
            ordering: channel.ordering,
            counterparty: expectedCounterparty,
            connectionHops: getCounterpartyHops(channel.connectionHops[0]),
            version: message.counterpartyVersion
        });
        require(
            verifyChannelState(
                connection,
                message.proofHeight,
                message.proofTry,
                channel.counterparty.portId,
                message.counterpartyChannelId,
                abi.encode(expectedChannel)
            ),
            "failed to verify channel state"
        );
        channel.state = ChannelState.OPEN;
        channel.version = message.counterpartyVersion;
        channel.counterparty.channelId = message.counterpartyChannelId;
        updateChannelCommitment(message.portId, message.channelId);

        emit ChannelOpenAck(
            message.portId,
            message.channelId,
            channel.connectionHops[0],
            channel.counterparty.portId,
            channel.counterparty.channelId
        );
    }

    event ChannelOpenConfirm(
        string portId,
        string channelId,
        string connectionId,
        string counterpartyPortId,
        string counterpartyChannelId
    );

    /**
     * @dev channelOpenConfirm is called by the counterparty module to close their end of the channel, since the other end has been closed.
     */
    function channelOpenConfirm(MsgChannelOpenConfirm calldata message) external {
        ChannelEnd storage channel = channels[message.portId][message.channelId];
        require(channel.state == ChannelState.TRYOPEN, "channel state is not TRYOPEN");

        // TODO authenticates a port binding

        ConnectionEnd storage connection = connections[channel.connectionHops[0]];
        require(connection.state == ConnectionState.OPEN, "connection state is not OPEN");
        require(channel.connectionHops.length == 1);

        ChannelCounterparty memory expectedCounterparty = ChannelCounterparty({
            portId: message.portId,
            channelId: message.channelId
        });
        ChannelEnd memory expectedChannel = ChannelEnd({
            state: ChannelState.OPEN,
            ordering: channel.ordering,
            counterparty: expectedCounterparty,
            connectionHops: getCounterpartyHops(channel.connectionHops[0]),
            version: channel.version
        });
        require(
            verifyChannelState(
                connection,
                message.proofHeight,
                message.proofAck,
                channel.counterparty.portId,
                channel.counterparty.channelId,
                abi.encode(expectedChannel)
            ),
            "failed to verify channel state"
        );
        channel.state = ChannelState.OPEN;
        updateChannelCommitment(message.portId, message.channelId);
        emit ChannelOpenConfirm(
            message.portId,
            message.channelId,
            channel.connectionHops[0],
            channel.counterparty.portId,
            channel.counterparty.channelId
        );
    }

    event ChannelCloseInit(
        string portId,
        string channelId,
        string connectionId,
        string counterpartyPortId,
        string counterpartyChannelId
    );

    /**
     * @dev channelCloseInit is called by either module to close their end of the channel. Once closed, channels cannot be reopened.
     */
    function channelCloseInit(MsgChannelCloseInit calldata message) external {
        ChannelEnd storage channel = channels[message.portId][message.channelId];
        require(channel.state != ChannelState.CLOSED, "channel state is already CLOSED");

        // TODO authenticates a port binding

        ConnectionEnd storage connection = connections[channel.connectionHops[0]];
        require(connection.state == ConnectionState.OPEN, "connection state is not OPEN");

        channel.state = ChannelState.CLOSED;
        updateChannelCommitment(message.portId, message.channelId);
        emit ChannelCloseInit(
            message.portId,
            message.channelId,
            channel.connectionHops[0],
            channel.counterparty.portId,
            channel.counterparty.channelId
        );
    }

    event ChannelCloseConfirm(
        string portId,
        string channelId,
        string connectionId,
        string counterpartyPortId,
        string counterpartyChannelId
    );

    /**
     * @dev channelCloseConfirm is called by the counterparty module to close their end of the
     * channel, since the other end has been closed.
     */
    function channelCloseConfirm(MsgChannelCloseConfirm calldata message) external {
        ChannelEnd storage channel = channels[message.portId][message.channelId];
        require(channel.state != ChannelState.CLOSED, "channel state is already CLOSED");

        // TODO authenticates a port binding

        require(channel.connectionHops.length == 1);
        ConnectionEnd storage connection = connections[channel.connectionHops[0]];
        require(connection.state == ConnectionState.OPEN, "connection state is not OPEN");

        ChannelCounterparty memory expectedCounterparty = ChannelCounterparty({
            portId: message.portId,
            channelId: message.channelId
        });
        ChannelEnd memory expectedChannel = ChannelEnd({
            state: ChannelState.CLOSED,
            ordering: channel.ordering,
            counterparty: expectedCounterparty,
            connectionHops: getCounterpartyHops(channel.connectionHops[0]),
            version: channel.version
        });
        require(
            verifyChannelState(
                connection,
                message.proofHeight,
                message.proofInit,
                channel.counterparty.portId,
                channel.counterparty.channelId,
                abi.encode(expectedChannel)
            ),
            "failed to verify channel state"
        );
        channel.state = ChannelState.CLOSED;
        updateChannelCommitment(message.portId, message.channelId);
        emit ChannelCloseConfirm(
            message.portId,
            message.channelId,
            channel.connectionHops[0],
            channel.counterparty.portId,
            channel.counterparty.channelId
        );
    }

    function updateChannelCommitment(string memory portId, string memory channelId) private {
        commitments[IBCCommitment.channelCommitmentKey(portId, channelId)] = keccak256(
            abi.encode(channels[portId][channelId])
        );
    }

    /* Verification functions */

    function verifyChannelState(
        ConnectionEnd storage connection,
        Height calldata height,
        bytes calldata proof,
        string memory portId,
        string memory channelId,
        bytes memory channelBytes
    ) private returns (bool) {
        return
            getClient(connection.clientId).verifyMembership(
                connection.clientId,
                height,
                0,
                0,
                proof,
                connection.counterparty.prefix,
                IBCCommitment.channelPath(portId, channelId),
                channelBytes
            );
    }

    /* Internal functions */

    function getCounterpartyHops(string memory connectionId) internal view returns (string[] memory hops) {
        hops = new string[](1);
        hops[0] = connections[connectionId].counterparty.connectionId;
        return hops;
    }

    function generateChannelIdentifier() private returns (string memory) {
        string memory identifier = string(abi.encode("channel-", Strings.toString(nextChannelSequence)));
        nextChannelSequence++;
        return identifier;
    }
}
