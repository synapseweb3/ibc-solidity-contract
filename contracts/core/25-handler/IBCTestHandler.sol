// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./IBCClientHandler.sol";
import "./IBCConnectionHandler.sol";
import "./IBCChannelHandler.sol";
import "./IBCPacketHandler.sol";
import "../../clients/MockClient.sol";
import "../02-client/ILightClient.sol";

/**
 * @dev IBCHandler is a contract that implements [ICS-25](https://github.com/cosmos/ibc/tree/main/spec/core/ics-025-handler-interface).
 */
contract IBCTestHandler is
    IBCHost,
    IBCClientHandler,
    IBCConnectionHandler,
    IBCChannelHandler,
    IBCPacketHandler
{
    constructor(address ibcClient, address ibcConnection, address ibcChannel, address ibcPacket)
        IBCClientHandler(ibcClient)
        IBCConnectionHandler(ibcConnection)
        IBCChannelHandler(ibcChannel)
        IBCPacketHandler(ibcPacket)
    {}
}
