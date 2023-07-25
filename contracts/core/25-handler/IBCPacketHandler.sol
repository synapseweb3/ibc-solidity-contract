// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "../25-handler/IBCMsgs.sol";
import "../24-host/IBCHost.sol";
import "../04-channel/IIBCChannel.sol";
import "../05-port/ModuleManager.sol";
import "../05-port/IIBCModule.sol";
import "./IBCUtil.sol";

/**
 * @dev IBCPacketHandler is a contract that calls a contract that implements `IIBCPacket` with delegatecall.
 */
abstract contract IBCPacketHandler is Context, ModuleManager {
    // IBC Packet contract address
    address immutable ibcChannelPacketAddress;

    // Events
    event SendPacket(Packet.Data packet);
    event ReceivePacket(Packet.Data packet);
    event WriteAcknowledgement(Packet.Data packet, bytes acknowledgement);
    event AcknowledgePacket(Packet.Data packet, bytes acknowledgement);

    constructor(address ibcChannelPacket) {
        ibcChannelPacketAddress = ibcChannelPacket;
    }

    function sendPacket(Packet.Data calldata packet) external {
        require(
            authenticateCapability(
                channelCapabilityPath(packet.sourcePort, packet.sourceChannel)
            ),
            "channel capability failed on authentication"
        );
        (bool success, bytes memory res) = ibcChannelPacketAddress.delegatecall(
            abi.encodeWithSelector(IIBCPacket.sendPacket.selector, packet)
        );
        IBCUtil.process_delgatecall(success, res, "sendPacket");
        emit SendPacket(packet);
    }

    function recvPacket(IBCMsgs.MsgPacketRecv calldata msg_) external {
        IIBCModule module = lookupModuleByChannel(
            msg_.packet.destinationPort,
            msg_.packet.destinationChannel
        );
        bytes memory acknowledgement = module.onRecvPacket(
            msg_.packet,
            _msgSender()
        );
        (bool success, bytes memory res) = ibcChannelPacketAddress.delegatecall(
            abi.encodeWithSelector(IIBCPacket.recvPacket.selector, msg_)
        );
        IBCUtil.process_delgatecall(success, res, "recvPacket");
        if (acknowledgement.length > 0) {
            (success, ) = ibcChannelPacketAddress.delegatecall(
                abi.encodeWithSelector(
                    IIBCPacket.writeAcknowledgement.selector,
                    msg_.packet.destinationPort,
                    msg_.packet.destinationChannel,
                    msg_.packet.sequence,
                    acknowledgement
                )
            );
            require(success);
            emit WriteAcknowledgement(msg_.packet, acknowledgement);
        }
        emit ReceivePacket(msg_.packet);
    }

    function writeAcknowledgement(
        Packet.Data calldata packet,
        bytes calldata acknowledgement
    ) external {
        string memory destinationPortId = packet.destinationPort;
        string memory destinationChannel = packet.destinationChannel;
        require(
            authenticateCapability(
                channelCapabilityPath(destinationPortId, destinationChannel)
            ),
            "channel capability failed on authentication"
        );
        (bool success, bytes memory res) = ibcChannelPacketAddress.delegatecall(
            abi.encodeWithSelector(
                IIBCPacket.writeAcknowledgement.selector,
                destinationPortId,
                destinationChannel,
                packet.sequence,
                acknowledgement
            )
        );
        IBCUtil.process_delgatecall(success, res, "writeAcknowledgement");
        emit WriteAcknowledgement(packet, acknowledgement);
    }

    function acknowledgePacket(
        IBCMsgs.MsgPacketAcknowledgement calldata msg_
    ) external {
        IIBCModule module = lookupModuleByChannel(
            msg_.packet.sourcePort,
            msg_.packet.sourceChannel
        );
        module.onAcknowledgementPacket(
            msg_.packet,
            msg_.acknowledgement,
            _msgSender()
        );
        (bool success, bytes memory res) = ibcChannelPacketAddress.delegatecall(
            abi.encodeWithSelector(IIBCPacket.acknowledgePacket.selector, msg_)
        );
        IBCUtil.process_delgatecall(success, res, "acknowledgePacket");
        emit AcknowledgePacket(msg_.packet, msg_.acknowledgement);
    }
}
