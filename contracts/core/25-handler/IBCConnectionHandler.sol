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
    event OpenAckConnection(string connectionId, string clientId, string counterpartyConnectionId, string counterpartyClientId);
    event OpenConfirmConnection(string connectionId, string clientId, string counterpartyConnectionId, string counterpartyClientId);

    constructor(address ibcConnection) {
        ibcConnectionAddress = ibcConnection;
    }

    function connectionOpenInit(IBCMsgs.MsgConnectionOpenInit calldata msg_)
        external
        returns (ConnectionEnd.Attributes memory attr)
    {
        (bool success, bytes memory res) = ibcConnectionAddress.delegatecall(
            abi.encodeWithSelector(IIBCConnectionHandshake.connectionOpenInit.selector, msg_)
        );
        require(success);
        attr = abi.decode(res, (ConnectionEnd.Attributes));
        emit OpenInitConnection(attr.connectionId, attr.clientId, attr.counterpartyConnectionId, attr.counterpartyClientId);
        return attr;
    }

    function connectionOpenTry(IBCMsgs.MsgConnectionOpenTry calldata msg_)
        external
        returns (ConnectionEnd.Attributes memory attr)
    {
        (bool success, bytes memory res) = ibcConnectionAddress.delegatecall(
            abi.encodeWithSelector(IIBCConnectionHandshake.connectionOpenTry.selector, msg_)
        );
        require(success);
        attr = abi.decode(res, (ConnectionEnd.Attributes));
        emit OpenTryConnection(attr.connectionId, attr.clientId, attr.counterpartyConnectionId, attr.counterpartyClientId);
        return attr;
    }

    function connectionOpenAck(IBCMsgs.MsgConnectionOpenAck calldata msg_)
        external
        returns (ConnectionEnd.Attributes memory attr)
    {
        (bool success, bytes memory res) = ibcConnectionAddress.delegatecall(
            abi.encodeWithSelector(IIBCConnectionHandshake.connectionOpenAck.selector, msg_)
        );
        require(success);
        attr = abi.decode(res, (ConnectionEnd.Attributes));
        emit OpenAckConnection(attr.connectionId, attr.clientId, attr.counterpartyConnectionId, attr.counterpartyClientId);
        return attr;
    }

    function connectionOpenConfirm(IBCMsgs.MsgConnectionOpenConfirm calldata msg_)
        external
        returns (ConnectionEnd.Attributes memory attr)
    {
        (bool success, bytes memory res) = ibcConnectionAddress.delegatecall(
            abi.encodeWithSelector(IIBCConnectionHandshake.connectionOpenConfirm.selector, msg_)
        );
        require(success);
        attr = abi.decode(res, (ConnectionEnd.Attributes));
        emit OpenConfirmConnection(attr.connectionId, attr.clientId, attr.counterpartyConnectionId, attr.counterpartyClientId);
        return attr;
    }
}
