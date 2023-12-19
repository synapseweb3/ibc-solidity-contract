// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../core/02-client/ILightClient.sol";
import "../core/02-client/IBCHeight.sol";
import "../proto/Client.sol";
import "./CkbProof.sol";

// MokkClient implements https://github.com/datachainlab/ibc-mock-client
// WARNING: This client is intended to be used for testing purpose. Therefore, it is not generally available in a production, except in a fully trusted environment.
contract CkbClient is ILightClient {
    using CkbProof for *;
    uint64 private constant MAX_UINT64 = 18446744073709551615;
    constructor() {}

    /**
     * @dev createClient creates a new client with the given state
     */
    function createClient(string calldata, bytes calldata, bytes calldata)
        external pure override returns (bytes32 clientStateCommitment, ConsensusStateUpdate memory update, bool ok)
    {
        return (
            bytes32(""),
            ConsensusStateUpdate({
                consensusStateCommitment: bytes32(""),
                height: Height.Data({revisionNumber: 0, revisionHeight: MAX_UINT64})
            }),
            true
        );
    }

    /**
     * @dev getTimestampAtHeight returns the timestamp of the consensus state at the given height.
     */
    function getTimestampAtHeight(string calldata, Height.Data calldata)
        external pure override returns (uint64, bool)
    {
        return (MAX_UINT64, true);
    }

    /**
     * @dev getLatestHeight returns the latest height of the client state corresponding to `clientId`.
     */
    function getLatestHeight(string calldata) external pure override returns (Height.Data memory, bool) {
        return (Height.Data({revisionNumber: 0, revisionHeight: MAX_UINT64}), true);
    }

    /**
     * @dev updateClient is intended to perform the followings:
     * 1. verify a given client message(e.g. header)
     * 2. check misbehaviour such like duplicate block height
     * 3. if misbehaviour is found, update state accordingly and return
     * 4. update state(s) with the client message
     * 5. persist the state(s) on the host
     */
    function updateClient(string calldata, bytes calldata)
        external pure override returns (bytes32 clientStateCommitment, ConsensusStateUpdate[] memory updates, bool ok)
    {
        return (bytes32(0), new ConsensusStateUpdate[](0), true);
    }

    /**
     * @dev verifyMembership is a generic proof verification method which verifies a proof of the existence of a value at a given CommitmentPath at the specified height.
     * The caller is expected to construct the full CommitmentPath from a CommitmentPrefix and a standardized path (as defined in ICS 24).
     */
    function verifyMembership(
        string calldata,
        Height.Data calldata,
        uint64,
        uint64,
        bytes calldata proof,
        bytes memory,
        bytes memory path,
        bytes calldata value
    ) external override returns (bool) {
        return CkbProof.verifyProof(proof, path, value);
    }

    /**
     * @dev verifyNonMembership is a generic proof verification method which verifies the absence of a given CommitmentPath at a specified height.
     * The caller is expected to construct the full CommitmentPath from a CommitmentPrefix and a standardized path (as defined in ICS 24).
     */
    function verifyNonMembership(
        string calldata,
        Height.Data calldata,
        uint64,
        uint64,
        bytes calldata,
        bytes memory,
        bytes memory
    ) external pure override returns (bool) {
        return true;
    }

    /* State accessors */

    /**
     * @dev getClientState returns the clientState corresponding to `clientId`.
     *      If it's not found, the function returns false.
     */
    function getClientState(string calldata) external pure returns (bytes memory clientStateBytes, bool) {
        return (bytes(""), true);
    }

    /**
     * @dev getConsensusState returns the consensusState corresponding to `clientId` and `height`.
     *      If it's not found, the function returns false.
     */
    function getConsensusState(string calldata, Height.Data calldata)
        external pure returns (bytes memory consensusStateBytes, bool)
    {
        return (bytes(""), true);
    }

}
