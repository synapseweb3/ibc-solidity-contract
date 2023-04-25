// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../25-handler/IBCMsgs.sol";
import "../24-host/IBCHost.sol";
import "../04-channel/IIBCChannel.sol";
import "../05-port/IIBCModule.sol";
import "../05-port/ModuleManager.sol";

/**
 * @dev IBCChannelHandler is a contract that calls a contract that implements `IIBCChannelHandshake` with delegatecall.
 */
abstract contract IBCChannelHandler is ModuleManager {
    // IBC Channel contract address
    address immutable ibcChannelAddress;

    event OpenInitChannel(string portId, string channelId, string connectionId, string counterpartyPortId, string counterpartyChannelId);
    event OpenTryChannel(string portId, string channelId, string connectionId, string counterpartyPortId, string counterpartyChannelId);
    event OpenAckChannel(string portId, string channelId, string counterpartyChannelId);
    event OpenConfirmChannel(string portId, string channelId);
    event CloseInitChannel(string portId, string channelId);
    event CloseConfirmChannel(string portId, string channelId);

    constructor(address ibcChannel) {
        ibcChannelAddress = ibcChannel;
    }

    function channelOpenInit(IBCMsgs.MsgChannelOpenInit calldata msg_) external returns (string memory channelId) {
        (bool success, bytes memory res) =
            ibcChannelAddress.delegatecall(abi.encodeWithSelector(IIBCChannelHandshake.channelOpenInit.selector, msg_));
        require(success);
        channelId = abi.decode(res, (string));

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
        emit OpenInitChannel(msg_.portId, channelId, msg_.channel.connectionHops[0], msg_.channel.counterparty.portId, msg_.channel.counterparty.channelId);
        return channelId;
    }

    function channelOpenTry(IBCMsgs.MsgChannelOpenTry calldata msg_) external returns (string memory channelId) {
        {
            // avoid "Stack too deep" error
            (bool success, bytes memory res) = ibcChannelAddress.delegatecall(
                abi.encodeWithSelector(IIBCChannelHandshake.channelOpenTry.selector, msg_)
            );
            require(success);
            channelId = abi.decode(res, (string));
        }
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
        emit OpenTryChannel(msg_.portId, channelId, msg_.channel.connectionHops[0], msg_.channel.counterparty.portId, msg_.channel.counterparty.channelId);
        return channelId;
    }

    function channelOpenAck(IBCMsgs.MsgChannelOpenAck calldata msg_) external {
        (bool success,) =
            ibcChannelAddress.delegatecall(abi.encodeWithSelector(IIBCChannelHandshake.channelOpenAck.selector, msg_));
        require(success);
        lookupModuleByPort(msg_.portId).onChanOpenAck(msg_.portId, msg_.channelId, msg_.counterpartyVersion);
        emit OpenAckChannel(msg_.portId, msg_.channelId, msg_.counterpartyChannelId);
    }

    function channelOpenConfirm(IBCMsgs.MsgChannelOpenConfirm calldata msg_) external {
        (bool success,) = ibcChannelAddress.delegatecall(
            abi.encodeWithSelector(IIBCChannelHandshake.channelOpenConfirm.selector, msg_)
        );
        require(success);
        lookupModuleByPort(msg_.portId).onChanOpenConfirm(msg_.portId, msg_.channelId);
        emit OpenConfirmChannel(msg_.portId, msg_.channelId);
    }

    function channelCloseInit(IBCMsgs.MsgChannelCloseInit calldata msg_) external {
        (bool success,) =
            ibcChannelAddress.delegatecall(abi.encodeWithSelector(IIBCChannelHandshake.channelCloseInit.selector, msg_));
        require(success);
        lookupModuleByPort(msg_.portId).onChanCloseInit(msg_.portId, msg_.channelId);
        emit CloseInitChannel(msg_.portId, msg_.channelId);
    }

    function channelCloseConfirm(IBCMsgs.MsgChannelCloseConfirm calldata msg_) external {
        (bool success,) = ibcChannelAddress.delegatecall(
            abi.encodeWithSelector(IIBCChannelHandshake.channelCloseConfirm.selector, msg_)
        );
        require(success);
        lookupModuleByPort(msg_.portId).onChanCloseConfirm(msg_.portId, msg_.channelId);
        emit CloseConfirmChannel(msg_.portId, msg_.channelId);
    }
}
