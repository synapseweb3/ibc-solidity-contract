// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../24-host/IBCHost.sol";
import "../02-client/IIBCClient.sol";

/**
 * @dev IBCClientHandler is a contract that calls a contract that implements `IIBCClient` with delegatecall.
 */
abstract contract IBCClientHandler {
    // IBC Client contract address
    address immutable ibcClientAddress;

    event CreateClient(string clientId, string clientType);
    event UpdateClient(string clientId, bytes clientMessage);

    constructor(address ibcClient) {
        ibcClientAddress = ibcClient;
    }

    /**
     * @dev registerClient registers a new client type into the client registry
     */
    function registerClient(string calldata clientType, ILightClient client) public virtual {
        (bool success,) = ibcClientAddress.delegatecall(
            abi.encodeWithSelector(IIBCClient.registerClient.selector, clientType, client)
        );
        require(success);
    }

    /**
     * @dev createClient creates a new client state and populates it with a given consensus state
     */
    function createClient(IBCMsgs.MsgCreateClient calldata msg_) external returns (string memory clientId) {
        (bool success, bytes memory res) =
            ibcClientAddress.delegatecall(abi.encodeWithSelector(IIBCClient.createClient.selector, msg_));
        require(success);
        clientId = abi.decode(res, (string));
        emit CreateClient(clientId, msg_.clientType);
        return clientId;
    }

    /**
     * @dev updateClient updates the consensus state and the state root from a provided header
     */
    function updateClient(IBCMsgs.MsgUpdateClient calldata msg_) external {
        (bool success,) = ibcClientAddress.delegatecall(abi.encodeWithSelector(IIBCClient.updateClient.selector, msg_));
        require(success);
        emit UpdateClient(msg_.clientId, msg_.clientMessage);
    }
}
