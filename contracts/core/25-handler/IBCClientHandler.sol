// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../24-host/IBCHost.sol";
import "../02-client/IIBCClient.sol";
import "./IBCUtil.sol";

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
    function registerClient(
        string calldata clientType,
        ILightClient client
    ) public virtual {
        (bool success, ) = ibcClientAddress.delegatecall(
            abi.encodeWithSelector(
                IIBCClient.registerClient.selector,
                clientType,
                client
            )
        );
        IBCUtil.check_delegatecall(success, "", "registerClient");
    }

    /**
     * @dev createClient creates a new client state and populates it with a given consensus state
     */
    function createClient(
        IBCMsgs.MsgCreateClient calldata msg_
    ) external returns (string memory clientId) {
        (bool success, bytes memory res) = ibcClientAddress.delegatecall(
            abi.encodeWithSelector(IIBCClient.createClient.selector, msg_)
        );
        IBCUtil.check_delegatecall(success, res, "createClient");
        clientId = abi.decode(res, (string));
        emit CreateClient(clientId, msg_.clientType);
        return clientId;
    }

    /**
     * @dev updateClient updates the consensus state and the state root from a provided header
     */
    function updateClient(IBCMsgs.MsgUpdateClient calldata msg_) external {
        (bool success, ) = ibcClientAddress.delegatecall(
            abi.encodeWithSelector(IIBCClient.updateClient.selector, msg_)
        );
        IBCUtil.check_delegatecall(success, "", "updateClient");
        emit UpdateClient(msg_.clientId, msg_.clientMessage);
    }
}
