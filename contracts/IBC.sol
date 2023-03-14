// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./types/Msg.sol";
import "./types/State.sol";
import "./ILightClient.sol";
import "./IBCStore.sol";
import "./IBCClient.sol";
import "./IBCChannel.sol";
import "./IBCConnection.sol";
import "./IBCPacket.sol";

contract IBC is IBCClient, IBCConnection, IBCChannel, IBCPacket, Ownable {}
