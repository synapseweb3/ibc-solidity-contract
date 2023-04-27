// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../../proto/Client.sol";
import "../../proto/Connection.sol";
import "../25-handler/IBCMsgs.sol";
import "../24-host/IBCStore.sol";
import "../24-host/IBCCommitment.sol";
import "../03-connection/IIBCConnection.sol";

/**
 * @dev IBCConnection is a contract that implements [ICS-3](https://github.com/cosmos/ibc/tree/main/spec/core/ics-003-connection-semantics).
 */
contract IBCConnection is IBCStore, IIBCConnectionHandshake {
    string private constant commitmentPrefix = "ibc";

    /* Handshake functions */

    /**
     * @dev connectionOpenInit initialises a connection attempt on chain A. The generated connection identifier
     * is returned.
     */
    function connectionOpenInit(IBCMsgs.MsgConnectionOpenInit calldata msg_)
        external
        override
        returns (string memory)
    {
        string memory connectionId = generateConnectionIdentifier();
        ConnectionEnd.Data storage connection = connections[connectionId];
        require(connection.state == ConnectionEnd.State.Uninitialized, "connectionId already exists");
        connection.clientId = msg_.clientId;
        setSupportedVersions(connection.versions);
        connection.state = ConnectionEnd.State.Init;
        connection.delayPeriod = msg_.delayPeriod;
        connection.counterparty = msg_.counterparty;
        updateConnectionCommitment(connectionId);
        connectionIds.push(connectionId);
        clientConnectionIds[msg_.clientId].push(connectionId);
        return connectionId;
    }

    /**
     * @dev connectionOpenTry relays notice of a connection attempt on chain A to chain B (this
     * code is executed on chain B).
     */
    function connectionOpenTry(IBCMsgs.MsgConnectionOpenTry calldata msg_) external override returns (string memory) {
        require(validateSelfClient(msg_.clientState), "failed to validate self client state");
        require(msg_.counterpartyVersions.length > 0, "counterpartyVersions length must be greater than 0");

        string memory connectionId = generateConnectionIdentifier();
        ConnectionEnd.Data storage connection = connections[connectionId];
        require(connection.state == ConnectionEnd.State.Uninitialized, "connectionId already exists");
        connection.clientId = msg_.clientId;
        setSupportedVersions(connection.versions);
        connection.state = ConnectionEnd.State.TryOpen;
        connection.delayPeriod = msg_.delayPeriod;
        connection.counterparty = msg_.counterparty;

        ConnectionEnd.Data memory expectedConnection = ConnectionEnd.Data({
            clientId: msg_.counterparty.clientId,
            versions: msg_.counterpartyVersions,
            state: ConnectionEnd.State.Init,
            delayPeriod: msg_.delayPeriod,
            counterparty: Counterparty.Data({
                clientId: msg_.clientId,
                connectionId: "",
                prefix: MerklePrefix.Data({keyPrefix: bytes(commitmentPrefix)})
            })
        });

        require(
            verifyConnectionState(
                connection, msg_.proofHeight, msg_.proofInit, msg_.counterparty.connectionId, expectedConnection
            ),
            "failed to verify connection state"
        );
        require(
            verifyClientState(
                connection,
                msg_.proofHeight,
                IBCCommitment.clientStatePath(connection.counterparty.clientId),
                msg_.proofClient,
                msg_.clientState
            ),
            "failed to verify clientState"
        );
        // TODO we should also verify a consensus state

        updateConnectionCommitment(connectionId);
        connectionIds.push(connectionId);
        clientConnectionIds[msg_.clientId].push(connectionId);
        return connectionId;
    }

    /**
     * @dev connectionOpenAck relays acceptance of a connection open attempt from chain B back
     * to chain A (this code is executed on chain A).
     */
    function connectionOpenAck(IBCMsgs.MsgConnectionOpenAck calldata msg_) external override {
        ConnectionEnd.Data storage connection = connections[msg_.connectionId];
        if (connection.state != ConnectionEnd.State.Init && connection.state != ConnectionEnd.State.TryOpen)
        {
            revert("connection state is not INIT or TRYOPEN");
        } else if (connection.state == ConnectionEnd.State.Init && !isSupportedVersion(msg_.version)) {
            revert("connection state is in INIT but the provided version is not supported");
        } else if (
            connection.state == ConnectionEnd.State.TryOpen
                && (connection.versions.length != 1 || !isEqualVersion(connection.versions[0], msg_.version))
        ) {
            revert(
                "connection state is in TRYOPEN but the provided version is not set in the previous connection versions"
            );
        }

        require(validateSelfClient(msg_.clientState), "failed to validate self clien t state");

        Counterparty.Data memory expectedCounterparty = Counterparty.Data({
            clientId: connection.clientId,
            connectionId: msg_.connectionId,
            prefix: MerklePrefix.Data({keyPrefix: bytes(commitmentPrefix)})
        });

        ConnectionEnd.Data memory expectedConnection = ConnectionEnd.Data({
            clientId: connection.counterparty.clientId,
            versions: makeVersionArray(msg_.version),
            state: ConnectionEnd.State.TryOpen,
            delayPeriod: connection.delayPeriod,
            counterparty: expectedCounterparty
        });

        require(
            verifyConnectionState(
                connection, msg_.proofHeight, msg_.proofTry, msg_.counterpartyConnectionId, expectedConnection
            ),
            "failed to verify connection state"
        );
        require(
            verifyClientState(
                connection,
                msg_.proofHeight,
                IBCCommitment.clientStatePath(connection.counterparty.clientId),
                msg_.proofClient,
                msg_.clientState
            ),
            "failed to verify clientState"
        );
        // TODO we should also verify a consensus state

        connection.state = ConnectionEnd.State.Open;
        copyVersions(expectedConnection.versions, connection.versions);
        connection.counterparty.connectionId = msg_.counterpartyConnectionId;
        updateConnectionCommitment(msg_.connectionId);
    }

    /**
     * @dev connectionOpenConfirm confirms opening of a connection on chain A to chain B, after
     * which the connection is open on both chains (this code is executed on chain B).
     */
    function connectionOpenConfirm(IBCMsgs.MsgConnectionOpenConfirm calldata msg_) external override {
        ConnectionEnd.Data storage connection = connections[msg_.connectionId];
        require(connection.state == ConnectionEnd.State.TryOpen, "connection state is not TRYOPEN");

        Counterparty.Data memory expectedCounterparty = Counterparty.Data({
            clientId: connection.clientId,
            connectionId: msg_.connectionId,
            prefix: MerklePrefix.Data({keyPrefix: bytes(commitmentPrefix)})
        });

        ConnectionEnd.Data memory expectedConnection = ConnectionEnd.Data({
            clientId: connection.counterparty.clientId,
            versions: connection.versions,
            state: ConnectionEnd.State.Open,
            delayPeriod: connection.delayPeriod,
            counterparty: expectedCounterparty
        });

        require(
            verifyConnectionState(
                connection, msg_.proofHeight, msg_.proofAck, connection.counterparty.connectionId, expectedConnection
            ),
            "failed to verify connection state"
        );

        connection.state = ConnectionEnd.State.Open;
        updateConnectionCommitment(msg_.connectionId);
    }

    function updateConnectionCommitment(string memory connectionId) private {
        commitments[IBCCommitment.connectionCommitmentKey(connectionId)] =
            keccak256(ConnectionEnd.encode(connections[connectionId]));
    }

    /* Verification functions */

    function verifyClientState(
        ConnectionEnd.Data storage connection,
        Height.Data memory height,
        bytes memory path,
        bytes memory proof,
        bytes memory clientState
    ) private returns (bool) {
        return getClient(connection.clientId).verifyMembership(
            connection.clientId, height, 0, 0, proof, connection.counterparty.prefix.keyPrefix, path, clientState
        );
    }

    function verifyClientConsensusState(
        ConnectionEnd.Data storage connection,
        Height.Data memory height,
        Height.Data memory consensusHeight,
        bytes memory proof,
        bytes memory consensusState
    ) private returns (bool) {
        return getClient(connection.clientId).verifyMembership(
            connection.clientId,
            height,
            0,
            0,
            proof,
            connection.counterparty.prefix.keyPrefix,
            IBCCommitment.consensusStatePath(
                connection.counterparty.clientId, consensusHeight.revisionNumber, consensusHeight.revisionHeight
            ),
            consensusState
        );
    }

    function verifyConnectionState(
        ConnectionEnd.Data storage connection,
        Height.Data memory height,
        bytes memory proof,
        string memory connectionId,
        ConnectionEnd.Data memory counterpartyConnection
    ) private returns (bool) {
        return getClient(connection.clientId).verifyMembership(
            connection.clientId,
            height,
            0,
            0,
            proof,
            connection.counterparty.prefix.keyPrefix,
            IBCCommitment.connectionPath(connectionId),
            ConnectionEnd.encode(counterpartyConnection)
        );
    }

    /* Internal functions */

    function generateConnectionIdentifier() private returns (string memory) {
        string memory identifier = string(abi.encodePacked("connection-", Strings.toString(nextConnectionSequence)));
        nextConnectionSequence++;
        return identifier;
    }

    /**
     * @dev validateSelfClient validates the client parameters for a client of the host chain.
     *
     * NOTE: Developers can override this function to support an arbitrary EVM chain.
     */
    function validateSelfClient(bytes memory) internal view virtual returns (bool) {
        this; // this is a trick that suppresses "Warning: Function state mutability can be restricted to pure"
        return true;
    }

    /**
     * @dev setSupportedVersions sets the supported versions to a given array.
     *
     * NOTE: `versions` must be an empty array
     */
    function setSupportedVersions(Version.Data[] storage versions) internal {
        assert(versions.length == 0);
        versions.push(Version.Data({identifier: "1", features: new string[](2)}));
        Version.Data storage version = versions[0];
        version.features[0] = "ORDER_ORDERED";
        version.features[1] = "ORDER_UNORDERED";
    }

    // TODO implements
    function isSupportedVersion(Version.Data memory) internal pure returns (bool) {
        return true;
    }

    function isEqualVersion(Version.Data memory a, Version.Data memory b) internal pure returns (bool) {
        return keccak256(Version.encode(a)) == keccak256(Version.encode(b));
    }

    function makeVersionArray(Version.Data memory version) internal pure returns (Version.Data[] memory ret) {
        ret = new Version.Data[](1);
        ret[0] = version;
    }

    function copyVersions(Version.Data[] memory src, Version.Data[] storage dst) internal {
        for (uint256 i = 0; i < src.length; i++) {
            copyVersion(src[i], dst[i]);
        }
    }

    function copyVersion(Version.Data memory src, Version.Data storage dst) internal {
        dst.identifier = src.identifier;
        for (uint256 i = 0; i < src.features.length; i++) {
            dst.features[i] = src.features[i];
        }
    }
}
