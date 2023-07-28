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
 * @dev IBCChannelHandshake is a contract that implements [ICS-4](https://github.com/cosmos/ibc/tree/main/spec/core/ics-004-channel-and-packet-semantics).
 */
contract IBCChannelHandshake is IBCStore, IIBCChannelHandshake {
    using IBCHeight for Height.Data;

    /* Handshake functions */

    /**
     * @dev channelOpenInit is called by a module to initiate a channel opening handshake with a module on another chain.
     */
    function channelOpenInit(
        IBCMsgs.MsgChannelOpenInit calldata msg_
    ) external override returns (Channel.Attributes memory) {
        require(
            msg_.channel.connectionHops.length == 1,
            "connectionHops length must be 1"
        );
        ConnectionEnd.Data storage connection = connections[
            msg_.channel.connectionHops[0]
        ];
        require(
            connection.versions.length == 1,
            "single version must be negotiated on connection before opening channel"
        );
        require(
            msg_.channel.state == Channel.State.Init,
            "channel state must Init"
        );

        // TODO verifySupportedFeature

        // TODO authenticates a port binding

        string memory channelId = generateChannelIdentifier();
        channels[msg_.portId][channelId] = msg_.channel;
        nextSequenceSends[msg_.portId][channelId] = 1;
        nextSequenceRecvs[msg_.portId][channelId] = 1;
        nextSequenceAcks[msg_.portId][channelId] = 1;
        updateChannelCommitment(msg_.portId, channelId);

        channelIds.push(channelId);
        portChannelIds[msg_.portId].push(channelId);
        connectionPortIds[msg_.channel.connectionHops[0]].push(msg_.portId);
        return
            Channel.Attributes({
                portId: msg_.portId,
                connectionId: msg_.channel.connectionHops[0],
                channelId: channelId,
                counterpartyPortId: msg_.channel.counterparty.portId,
                counterpartyChannelId: msg_.channel.counterparty.channelId
            });
    }

    /**
     * @dev channelOpenTry is called by a module to accept the first step of a channel opening handshake initiated by a module on another chain.
     */
    function channelOpenTry(
        IBCMsgs.MsgChannelOpenTry calldata msg_
    ) external override returns (Channel.Attributes memory) {
        require(
            msg_.channel.connectionHops.length == 1,
            "connectionHops length must be 1"
        );
        ConnectionEnd.Data storage connection = connections[
            msg_.channel.connectionHops[0]
        ];
        require(
            connection.versions.length == 1,
            "single version must be negotiated on connection before opening channel"
        );
        require(
            msg_.channel.state == Channel.State.TryOpen,
            "channel state must be TryOpen"
        );

        // TODO verifySupportedFeature

        // TODO authenticates a port binding

        ChannelCounterparty.Data
            memory expectedCounterparty = ChannelCounterparty.Data({
                portId: msg_.portId,
                channelId: ""
            });
        Channel.Data memory expectedChannel = Channel.Data({
            state: Channel.State.Init,
            ordering: msg_.channel.ordering,
            counterparty: expectedCounterparty,
            connectionHops: getCounterpartyHops(msg_.channel.connectionHops[0]),
            version: msg_.counterpartyVersion
        });
        require(
            verifyChannelState(
                connection,
                msg_.proofHeight,
                msg_.proofInit,
                msg_.channel.counterparty.portId,
                msg_.channel.counterparty.channelId,
                Channel.encode(expectedChannel)
            ),
            "failed to verify channel state"
        );

        string memory channelId = generateChannelIdentifier();
        channels[msg_.portId][channelId] = msg_.channel;
        nextSequenceSends[msg_.portId][channelId] = 1;
        nextSequenceRecvs[msg_.portId][channelId] = 1;
        nextSequenceAcks[msg_.portId][channelId] = 1;
        updateChannelCommitment(msg_.portId, channelId);

        channelIds.push(channelId);
        portChannelIds[msg_.portId].push(channelId);
        connectionPortIds[msg_.channel.connectionHops[0]].push(msg_.portId);
        return
            Channel.Attributes({
                portId: msg_.portId,
                connectionId: msg_.channel.connectionHops[0],
                channelId: channelId,
                counterpartyPortId: msg_.channel.counterparty.portId,
                counterpartyChannelId: msg_.channel.counterparty.channelId
            });
    }

    /**
     * @dev channelOpenAck is called by the handshake-originating module to acknowledge the acceptance of the initial request by the counterparty module on the other chain.
     */
    function channelOpenAck(
        IBCMsgs.MsgChannelOpenAck calldata msg_
    ) external override returns (Channel.Attributes memory) {
        Channel.Data storage channel = channels[msg_.portId][msg_.channelId];
        require(
            channel.state == Channel.State.Init ||
                channel.state == Channel.State.TryOpen,
            "invalid channel state"
        );

        // TODO authenticates a port binding

        ConnectionEnd.Data storage connection = connections[
            channel.connectionHops[0]
        ];
        require(
            connection.state == ConnectionEnd.State.Open,
            "connection state is not OPEN"
        );
        require(channel.connectionHops.length == 1);

        ChannelCounterparty.Data
            memory expectedCounterparty = ChannelCounterparty.Data({
                portId: msg_.portId,
                channelId: msg_.channelId
            });
        Channel.Data memory expectedChannel = Channel.Data({
            state: Channel.State.TryOpen,
            ordering: channel.ordering,
            counterparty: expectedCounterparty,
            connectionHops: getCounterpartyHops(channel.connectionHops[0]),
            version: msg_.counterpartyVersion
        });
        require(
            verifyChannelState(
                connection,
                msg_.proofHeight,
                msg_.proofTry,
                channel.counterparty.portId,
                msg_.counterpartyChannelId,
                Channel.encode(expectedChannel)
            ),
            "failed to verify channel state"
        );
        channel.state = Channel.State.Open;
        channel.version = msg_.counterpartyVersion;
        channel.counterparty.channelId = msg_.counterpartyChannelId;
        updateChannelCommitment(msg_.portId, msg_.channelId);
        return
            Channel.Attributes({
                portId: msg_.portId,
                connectionId: channel.connectionHops[0],
                channelId: msg_.channelId,
                counterpartyPortId: channel.counterparty.portId,
                counterpartyChannelId: channel.counterparty.channelId
            });
    }

    /**
     * @dev channelOpenConfirm is called by the counterparty module to close their end of the channel, since the other end has been closed.
     */
    function channelOpenConfirm(
        IBCMsgs.MsgChannelOpenConfirm calldata msg_
    ) external override returns (Channel.Attributes memory) {
        Channel.Data storage channel = channels[msg_.portId][msg_.channelId];
        require(
            channel.state == Channel.State.TryOpen,
            "channel state is not TRYOPEN"
        );

        // TODO authenticates a port binding

        ConnectionEnd.Data storage connection = connections[
            channel.connectionHops[0]
        ];
        require(
            connection.state == ConnectionEnd.State.Open,
            "connection state is not OPEN"
        );
        require(channel.connectionHops.length == 1);

        ChannelCounterparty.Data
            memory expectedCounterparty = ChannelCounterparty.Data({
                portId: msg_.portId,
                channelId: msg_.channelId
            });
        Channel.Data memory expectedChannel = Channel.Data({
            state: Channel.State.Open,
            ordering: channel.ordering,
            counterparty: expectedCounterparty,
            connectionHops: getCounterpartyHops(channel.connectionHops[0]),
            version: channel.version
        });
        require(
            verifyChannelState(
                connection,
                msg_.proofHeight,
                msg_.proofAck,
                channel.counterparty.portId,
                channel.counterparty.channelId,
                Channel.encode(expectedChannel)
            ),
            "failed to verify channel state"
        );
        channel.state = Channel.State.Open;
        updateChannelCommitment(msg_.portId, msg_.channelId);
        return
            Channel.Attributes({
                portId: msg_.portId,
                connectionId: channel.connectionHops[0],
                channelId: msg_.channelId,
                counterpartyPortId: channel.counterparty.portId,
                counterpartyChannelId: channel.counterparty.channelId
            });
    }

    /**
     * @dev channelCloseInit is called by either module to close their end of the channel. Once closed, channels cannot be reopened.
     */
    function channelCloseInit(
        IBCMsgs.MsgChannelCloseInit calldata msg_
    ) external override returns (Channel.Attributes memory) {
        Channel.Data storage channel = channels[msg_.portId][msg_.channelId];
        require(
            channel.state != Channel.State.Closed,
            "channel state is already CLOSED"
        );

        // TODO authenticates a port binding

        ConnectionEnd.Data storage connection = connections[
            channel.connectionHops[0]
        ];
        require(
            connection.state == ConnectionEnd.State.Open,
            "connection state is not OPEN"
        );

        channel.state = Channel.State.Closed;
        updateChannelCommitment(msg_.portId, msg_.channelId);
        return
            Channel.Attributes({
                portId: msg_.portId,
                connectionId: channel.connectionHops[0],
                channelId: msg_.channelId,
                counterpartyPortId: channel.counterparty.portId,
                counterpartyChannelId: channel.counterparty.channelId
            });
    }

    /**
     * @dev channelCloseConfirm is called by the counterparty module to close their end of the
     * channel, since the other end has been closed.
     */
    function channelCloseConfirm(
        IBCMsgs.MsgChannelCloseConfirm calldata msg_
    ) external override returns (Channel.Attributes memory) {
        Channel.Data storage channel = channels[msg_.portId][msg_.channelId];
        require(
            channel.state != Channel.State.Closed,
            "channel state is already CLOSED"
        );

        // TODO authenticates a port binding

        require(channel.connectionHops.length == 1);
        ConnectionEnd.Data storage connection = connections[
            channel.connectionHops[0]
        ];
        require(
            connection.state == ConnectionEnd.State.Open,
            "connection state is not OPEN"
        );

        ChannelCounterparty.Data
            memory expectedCounterparty = ChannelCounterparty.Data({
                portId: msg_.portId,
                channelId: msg_.channelId
            });
        Channel.Data memory expectedChannel = Channel.Data({
            state: Channel.State.Closed,
            ordering: channel.ordering,
            counterparty: expectedCounterparty,
            connectionHops: getCounterpartyHops(channel.connectionHops[0]),
            version: channel.version
        });
        require(
            verifyChannelState(
                connection,
                msg_.proofHeight,
                msg_.proofInit,
                channel.counterparty.portId,
                channel.counterparty.channelId,
                Channel.encode(expectedChannel)
            ),
            "failed to verify channel state"
        );
        channel.state = Channel.State.Closed;
        updateChannelCommitment(msg_.portId, msg_.channelId);
        return
            Channel.Attributes({
                portId: msg_.portId,
                connectionId: channel.connectionHops[0],
                channelId: msg_.channelId,
                counterpartyPortId: channel.counterparty.portId,
                counterpartyChannelId: channel.counterparty.channelId
            });
    }

    function updateChannelCommitment(
        string memory portId,
        string memory channelId
    ) private {
        commitments[
            IBCCommitment.channelCommitmentKey(portId, channelId)
        ] = keccak256(Channel.encode(channels[portId][channelId]));
    }

    /* Verification functions */

    function verifyChannelState(
        ConnectionEnd.Data storage connection,
        Height.Data calldata height,
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
                connection.counterparty.prefix.keyPrefix,
                IBCCommitment.channelPath(portId, channelId),
                channelBytes
            );
    }

    /* Internal functions */

    function getCounterpartyHops(
        string memory connectionId
    ) internal view returns (string[] memory hops) {
        hops = new string[](1);
        hops[0] = connections[connectionId].counterparty.connectionId;
        return hops;
    }

    function generateChannelIdentifier() private returns (string memory) {
        string memory identifier = string(
            abi.encodePacked("channel-", Strings.toString(nextChannelSequence))
        );
        nextChannelSequence++;
        return identifier;
    }
}
