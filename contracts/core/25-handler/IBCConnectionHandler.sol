// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../25-handler/IBCMsgs.sol";
import "../24-host/IBCHost.sol";
import "../03-connection/IIBCConnection.sol";

/**
 * @dev IBCConnectionHandler is a contract that calls a contract that implements `IIBCConnectionHandshake` with delegatecall.
 */
abstract contract IBCConnectionHandler {
    // IBC Connection contract address
    address immutable ibcConnectionAddress;

    event OpenInitConnection(string connectionId, string clientId, string counterpartyConnectionId, string counterpartyClientId);
    event OpenTryConnection(string connectionId, string clientId, string counterpartyConnectionId, string counterpartyClientId);
    event OpenAckConnection(string connectionId, string counterpartyConnectionId);
    event OpenConfirmConnection(string connectionId);

    constructor(address ibcConnection) {
        ibcConnectionAddress = ibcConnection;
    }

    function connectionOpenInit(IBCMsgs.MsgConnectionOpenInit calldata msg_)
        external
        returns (string memory connectionId)
    {
        (bool success, bytes memory res) = ibcConnectionAddress.delegatecall(
            abi.encodeWithSelector(IIBCConnectionHandshake.connectionOpenInit.selector, msg_)
        );
        require(success);
        connectionId = abi.decode(res, (string));
        emit OpenInitConnection(connectionId, msg_.clientId, msg_.counterparty.connectionId, msg_.counterparty.clientId);
        return connectionId;
    }

    function connectionOpenTry(IBCMsgs.MsgConnectionOpenTry calldata msg_)
        external
        returns (string memory connectionId)
    {
        (bool success, bytes memory res) = ibcConnectionAddress.delegatecall(
            abi.encodeWithSelector(IIBCConnectionHandshake.connectionOpenTry.selector, msg_)
        );
        require(success);
        connectionId = abi.decode(res, (string));
        emit OpenTryConnection(connectionId, msg_.clientId, msg_.counterparty.connectionId, msg_.counterparty.clientId);
        return connectionId;
    }

    function connectionOpenAck(IBCMsgs.MsgConnectionOpenAck calldata msg_) external {
        (bool success,) = ibcConnectionAddress.delegatecall(
            abi.encodeWithSelector(IIBCConnectionHandshake.connectionOpenAck.selector, msg_)
        );
        require(success);
        emit OpenAckConnection(msg_.connectionId, msg_.counterpartyConnectionId);
    }

    function connectionOpenConfirm(IBCMsgs.MsgConnectionOpenConfirm calldata msg_) external {
        (bool success,) = ibcConnectionAddress.delegatecall(
            abi.encodeWithSelector(IIBCConnectionHandshake.connectionOpenConfirm.selector, msg_)
        );
        require(success);
        emit OpenConfirmConnection(msg_.connectionId);
    }
}
