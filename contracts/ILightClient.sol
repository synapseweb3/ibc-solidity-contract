// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./types/Msg.sol";

interface ILightClient {
    function clientCreate(
        string memory clientId,
        MsgClientCreate memory message
    ) external returns (ClientState memory clientState, ConsensusStateUpdate memory consensusStateUpdate, bool ok);

    function clientUpdate(
        string memory clientId,
        MsgClientUpdate memory message
    ) external returns (ClientState memory clientState, ConsensusStateUpdate[] memory consensusStateUpdates, bool ok);

    /**
     * @dev getTimestampAtHeight returns the timestamp of the consensus state at the given height.
     */
    function getTimestampAtHeight(
        string calldata clientId,
        Height calldata height
    ) external view returns (uint64, bool);

    /**
     * @dev getLatestHeight returns the latest height of the client state corresponding to `clientId`.
     */
    function getLatestHeight(string calldata clientId) external view returns (Height memory, bool);

    /**
     * @dev verifyMembership is a generic proof verification method which verifies a proof of the existence of a value at a given CommitmentPath at the specified height.
     * The caller is expected to construct the full CommitmentPath from a CommitmentPrefix and a standardized path (as defined in ICS 24).
     */
    function verifyMembership(
        string calldata clientId,
        Height calldata height,
        uint64 delayTimePeriod,
        uint64 delayBlockPeriod,
        bytes calldata proof,
        bytes calldata prefix,
        bytes calldata path,
        bytes calldata value
    ) external returns (bool);
}

struct ConsensusStateUpdate {
    ConsensusState consensusState;
    Height height;
}
