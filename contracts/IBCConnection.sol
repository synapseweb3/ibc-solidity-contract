// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./types/Msg.sol";
import "./IBCStore.sol";
import "./IBCCommitment.sol";

contract IBCConnection is IBCStore {
    string private constant commitmentPrefix = "ibc";

    function generateConnectionIdentifier() private returns (string memory) {
        string memory identifier = string(abi.encode("connection-", Strings.toString(nextConnectionSequence)));
        nextConnectionSequence++;
        return identifier;
    }

    event ConnectionOpenInit(
        string connectionId,
        string clientId,
        string counterpartyConnectionId,
        string counterpartyClientId
    );

    /**
     * @dev connectionOpenInit initialises a connection attempt on chain A. The generated connection identifier
     * is returned.
     */
    function connectionOpenInit(MsgConnectionOpenInit calldata message) external returns (string memory) {
        string memory connectionId = generateConnectionIdentifier();
        ConnectionEnd storage connection = connections[connectionId];
        require(connection.state == ConnectionState.UNKNOWN, "connectionId already exists");
        connection.state = ConnectionState.INIT;
        connection.clientId = message.clientId;
        setSupportedVersions(connection.versions);
        connection.delayPeriod = message.delayPeriod;
        connection.counterparty = message.counterparty;
        updateConnectionCommitment(connectionId);
        emit ConnectionOpenInit(
            connectionId,
            connection.clientId,
            connection.counterparty.connectionId,
            connection.counterparty.clientId
        );
        return connectionId;
    }

    event ConnectionOpenTry(
        string connectionId,
        string clientId,
        string counterpartyConnectionId,
        string counterpartyClientId
    );

    /**
     * @dev connectionOpenTry relays notice of a connection attempt on chain A to chain B (this
     * code is executed on chain B).
     */
    function connectionOpenTry(MsgConnectionOpenTry calldata message) external returns (string memory) {
        require(validateSelfClient(message.clientStateBytes), "failed to validate self client state");
        require(message.counterpartyVersions.length > 0, "counterpartyVersions length must be greater than 0");

        string memory connectionId = generateConnectionIdentifier();
        ConnectionEnd storage connection = connections[connectionId];
        require(connection.state == ConnectionState.UNKNOWN, "connectionId already exists");
        connection.clientId = message.clientId;
        setSupportedVersions(connection.versions);
        connection.state = ConnectionState.TRYOPEN;
        connection.delayPeriod = message.delayPeriod;
        connection.counterparty = message.counterparty;

        ConnectionEnd memory expectedConnection = ConnectionEnd({
            clientId: message.counterparty.clientId,
            versions: message.counterpartyVersions,
            state: ConnectionState.INIT,
            delayPeriod: message.delayPeriod,
            counterparty: Counterparty({clientId: message.clientId, connectionId: "", prefix: bytes(commitmentPrefix)})
        });

        require(
            verifyConnectionState(
                connection,
                message.proofHeight,
                message.proofInit,
                message.counterparty.connectionId,
                expectedConnection
            ),
            "failed to verify connection state"
        );
        require(
            verifyClientState(
                connection,
                message.proofHeight,
                IBCCommitment.clientStatePath(connection.counterparty.clientId),
                message.proofClient,
                message.clientStateBytes
            ),
            "failed to verify clientState"
        );
        // TODO we should also verify a consensus state
        updateConnectionCommitment(connectionId);
        emit ConnectionOpenTry(
            connectionId,
            connection.clientId,
            connection.counterparty.connectionId,
            connection.counterparty.clientId
        );
        return connectionId;
    }

    event ConnectionOpenAck(
        string connectionId,
        string clientId,
        string counterpartyConnectionId,
        string counterpartyClientId
    );

    /**
     * @dev connectionOpenAck relays acceptance of a connection open attempt from chain B back
     * to chain A (this code is executed on chain A).
     */
    function connectionOpenAck(MsgConnectionOpenAck calldata message) external {
        ConnectionEnd storage connection = connections[message.connectionId];
        if (connection.state != ConnectionState.INIT && connection.state != ConnectionState.TRYOPEN) {
            revert("connection state is not INIT or TRYOPEN");
        } else if (connection.state == ConnectionState.INIT && !isSupportedVersion(message.version)) {
            revert("connection state is in INIT but the provided version is not supported");
        } else if (
            connection.state == ConnectionState.TRYOPEN &&
            (connection.versions.length != 1 || !isEqualVersion(connection.versions[0], message.version))
        ) {
            revert(
                "connection state is in TRYOPEN but the provided version is not set in the previous connection versions"
            );
        }

        require(validateSelfClient(message.clientStateBytes), "failed to validate self client state");

        Counterparty memory expectedCounterparty = Counterparty({
            clientId: connection.clientId,
            connectionId: message.connectionId,
            prefix: bytes(commitmentPrefix)
        });

        ConnectionEnd memory expectedConnection = ConnectionEnd({
            clientId: connection.counterparty.clientId,
            versions: makeVersionArray(message.version),
            state: ConnectionState.TRYOPEN,
            delayPeriod: connection.delayPeriod,
            counterparty: expectedCounterparty
        });

        require(
            verifyConnectionState(
                connection,
                message.proofHeight,
                message.proofTry,
                message.counterpartyConnectionID,
                expectedConnection
            ),
            "failed to verify connection state"
        );
        require(
            verifyClientState(
                connection,
                message.proofHeight,
                IBCCommitment.clientStatePath(connection.counterparty.clientId),
                message.proofClient,
                message.clientStateBytes
            ),
            "failed to verify clientState"
        );
        // TODO we should also verify a consensus state

        connection.state = ConnectionState.OPEN;
        copyVersions(expectedConnection.versions, connection.versions);
        connection.counterparty.connectionId = message.counterpartyConnectionID;
        updateConnectionCommitment(message.connectionId);

        emit ConnectionOpenAck(
            message.connectionId,
            connection.clientId,
            connection.counterparty.connectionId,
            connection.counterparty.clientId
        );
    }

    event ConnectionOpenConfirm(
        string connectionId,
        string clientId,
        string counterpartyConnectionId,
        string counterpartyClientId
    );

    /**
     * @dev connectionOpenConfirm confirms opening of a connection on chain A to chain B, after
     * which the connection is open on both chains (this code is executed on chain B).
     */
    function connectionOpenConfirm(MsgConnectionOpenConfirm calldata message) external {
        ConnectionEnd storage connection = connections[message.connectionId];
        require(connection.state == ConnectionState.TRYOPEN, "connection state is not TRYOPEN");

        Counterparty memory expectedCounterparty = Counterparty({
            clientId: connection.clientId,
            connectionId: message.connectionId,
            prefix: bytes(commitmentPrefix)
        });

        ConnectionEnd memory expectedConnection = ConnectionEnd({
            clientId: connection.counterparty.clientId,
            versions: connection.versions,
            state: ConnectionState.OPEN,
            delayPeriod: connection.delayPeriod,
            counterparty: expectedCounterparty
        });

        require(
            verifyConnectionState(
                connection,
                message.proofHeight,
                message.proofAck,
                connection.counterparty.connectionId,
                expectedConnection
            ),
            "failed to verify connection state"
        );

        connection.state = ConnectionState.OPEN;
        updateConnectionCommitment(message.connectionId);
        emit ConnectionOpenConfirm(
            message.connectionId,
            connection.clientId,
            connection.counterparty.connectionId,
            connection.counterparty.clientId
        );
    }

    function updateConnectionCommitment(string memory connectionId) private {
        commitments[IBCCommitment.connectionCommitmentKey(connectionId)] = keccak256(
            abi.encode(connections[connectionId])
        );
    }

    /* Verification functions */

    function verifyClientState(
        ConnectionEnd storage connection,
        Height memory height,
        bytes memory path,
        bytes memory proof,
        bytes memory clientStateBytes
    ) private returns (bool) {
        return
            getClient(connection.clientId).verifyMembership(
                connection.clientId,
                height,
                0,
                0,
                proof,
                connection.counterparty.prefix,
                path,
                clientStateBytes
            );
    }

    function verifyConnectionState(
        ConnectionEnd storage connection,
        Height memory height,
        bytes memory proof,
        string memory connectionId,
        ConnectionEnd memory counterpartyConnection
    ) private returns (bool) {
        return
            getClient(connection.clientId).verifyMembership(
                connection.clientId,
                height,
                0,
                0,
                proof,
                connection.counterparty.prefix,
                IBCCommitment.connectionPath(connectionId),
                abi.encode(counterpartyConnection)
            );
    }

    /**
     * @dev validateSelfClient validates the client parameters for a client of the host chain.
     *
     * NOTE: Developers can this function to support an arbitrary EVM chain.
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
    function setSupportedVersions(Version[] storage versions) internal {
        assert(versions.length == 0);
        versions.push(Version({identifier: "1", features: new string[](2)}));
        Version storage version = versions[0];
        version.features[0] = "ORDER_ORDERED";
        version.features[1] = "ORDER_UNORDERED";
    }

    // TODO implements
    function isSupportedVersion(Version memory) internal pure returns (bool) {
        return true;
    }

    function isEqualVersion(Version memory a, Version memory b) internal pure returns (bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }

    function makeVersionArray(Version memory version) internal pure returns (Version[] memory ret) {
        ret = new Version[](1);
        ret[0] = version;
    }

    function copyVersions(Version[] memory src, Version[] storage dst) internal {
        for (uint256 i = 0; i < src.length; i++) {
            copyVersion(src[i], dst[i]);
        }
    }

    function copyVersion(Version memory src, Version storage dst) internal {
        dst.identifier = src.identifier;
        for (uint256 i = 0; i < src.features.length; i++) {
            dst.features[i] = src.features[i];
        }
    }
}
