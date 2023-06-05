// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../25-handler/IBCMsgs.sol";
import "../24-host/IBCHost.sol";
import "../04-channel/IIBCChannel.sol";
import "../05-port/IIBCModule.sol";
import "../05-port/ModuleManager.sol";
import "../../proto/Connection.sol";

/**
 * @dev IBCChannelHandler is a contract that calls a contract that implements `IIBCChannelHandshake` with delegatecall.
 */
abstract contract IBCChannelHandler is ModuleManager {
    // IBC Channel contract address
    address immutable ibcChannelAddress;

    event OpenInitChannel(string portId, string channelId, string connectionId, string counterpartyPortId, string counterpartyChannelId);
    event OpenTryChannel(string portId, string channelId, string connectionId, string counterpartyPortId, string counterpartyChannelId);
    event OpenAckChannel(string portId, string channelId, string connectionId, string counterpartyPortId, string counterpartyChannelId);
    event OpenConfirmChannel(string portId, string channelId, string connectionId, string counterpartyPortId, string counterpartyChannelId);
    event CloseInitChannel(string portId, string channelId, string connectionId, string counterpartyPortId, string counterpartyChannelId);
    event CloseConfirmChannel(string portId, string channelId, string connectionId, string counterpartyPortId, string counterpartyChannelId);

    constructor(address ibcChannel) {
        ibcChannelAddress = ibcChannel;
    }

    function channelOpenInit(IBCMsgs.MsgChannelOpenInit calldata msg_) external returns (Channel.Attributes memory attr) {
        (bool success, bytes memory res) =
            ibcChannelAddress.delegatecall(abi.encodeWithSelector(IIBCChannelHandshake.channelOpenInit.selector, msg_));
        require(success);

        attr = abi.decode(res, (Channel.Attributes));
        string memory channelId = attr.channelId;

        IIBCModule module = lookupModuleByPort(msg_.portId);
        module.onChanOpenInit(
            msg_.channel.ordering,
            msg_.channel.connectionHops,
            msg_.portId,
            channelId,
            msg_.channel.counterparty,
            msg_.channel.version
        );
        claimCapability(channelCapabilityPath(msg_.portId, channelId), address(module));
        claimCapability(channelCapabilityPath(msg_.portId, channelId), msg.sender);
        emit OpenInitChannel(attr.portId, attr.channelId, attr.connectionId, attr.counterpartyPortId, attr.counterpartyChannelId);
        return attr;
    }

    function channelOpenTry(IBCMsgs.MsgChannelOpenTry calldata msg_) external returns (Channel.Attributes memory attr) {
        {
            // avoid "Stack too deep" error
            (bool success, bytes memory res) = ibcChannelAddress.delegatecall(
                abi.encodeWithSelector(IIBCChannelHandshake.channelOpenTry.selector, msg_)
            );
            require(success);
            attr = abi.decode(res, (Channel.Attributes));
        }
        string memory channelId = attr.channelId;
        IIBCModule module = lookupModuleByPort(msg_.portId);
        module.onChanOpenTry(
            msg_.channel.ordering,
            msg_.channel.connectionHops,
            msg_.portId,
            channelId,
            msg_.channel.counterparty,
            msg_.channel.version,
            msg_.counterpartyVersion
        );
        claimCapability(channelCapabilityPath(msg_.portId, channelId), address(module));
        claimCapability(channelCapabilityPath(msg_.portId, channelId), msg.sender);
        emit OpenTryChannel(attr.portId, attr.channelId, attr.connectionId, attr.counterpartyPortId, attr.counterpartyChannelId);
        return attr;
    }

    function channelOpenAck(IBCMsgs.MsgChannelOpenAck calldata msg_) external returns (Channel.Attributes memory attr) {
        (bool success, bytes memory res) =
            ibcChannelAddress.delegatecall(abi.encodeWithSelector(IIBCChannelHandshake.channelOpenAck.selector, msg_));
        require(success);
        attr = abi.decode(res, (Channel.Attributes));
        lookupModuleByPort(msg_.portId).onChanOpenAck(msg_.portId, msg_.channelId, msg_.counterpartyVersion);
        emit OpenAckChannel(attr.portId, attr.channelId, attr.connectionId, attr.counterpartyPortId, attr.counterpartyChannelId);
        return attr;
    }

    function channelOpenConfirm(IBCMsgs.MsgChannelOpenConfirm calldata msg_) external returns (Channel.Attributes memory attr) {
        (bool success, bytes memory res) = ibcChannelAddress.delegatecall(
            abi.encodeWithSelector(IIBCChannelHandshake.channelOpenConfirm.selector, msg_)
        );
        require(success);
        attr = abi.decode(res, (Channel.Attributes));
        lookupModuleByPort(msg_.portId).onChanOpenConfirm(msg_.portId, msg_.channelId);
        emit OpenConfirmChannel(attr.portId, attr.channelId, attr.connectionId, attr.counterpartyPortId, attr.counterpartyChannelId);
        return attr;
    }

    function channelCloseInit(IBCMsgs.MsgChannelCloseInit calldata msg_) external returns (Channel.Attributes memory attr) {
        (bool success, bytes memory res) =
            ibcChannelAddress.delegatecall(abi.encodeWithSelector(IIBCChannelHandshake.channelCloseInit.selector, msg_));
        require(success);
        attr = abi.decode(res, (Channel.Attributes));
        lookupModuleByPort(msg_.portId).onChanCloseInit(msg_.portId, msg_.channelId);
        emit CloseInitChannel(attr.portId, attr.channelId, attr.connectionId, attr.counterpartyPortId, attr.counterpartyChannelId);
        return attr;
    }

    function channelCloseConfirm(IBCMsgs.MsgChannelCloseConfirm calldata msg_) external returns (Channel.Attributes memory attr) {
        (bool success, bytes memory res) = ibcChannelAddress.delegatecall(
            abi.encodeWithSelector(IIBCChannelHandshake.channelCloseConfirm.selector, msg_)
        );
        require(success);
        attr = abi.decode(res, (Channel.Attributes));
        lookupModuleByPort(msg_.portId).onChanCloseConfirm(msg_.portId, msg_.channelId);
        emit CloseConfirmChannel(attr.portId, attr.channelId, attr.connectionId, attr.counterpartyPortId, attr.counterpartyChannelId);
        return attr;
    }
}
