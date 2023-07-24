// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./ICS20Transfer.sol";

contract MockModule is ICS20Transfer {
    event TransferFrom(address, address, string, uint256);
    event Mint(address, string, uint256);
    event Burn(address, string, uint256);

    constructor(IBCHandler ibcHandler_) ICS20Transfer(ibcHandler_) {}

    function _transferFrom(
        address sender,
        address receiver,
        string memory denom,
        uint256 amount
    ) internal override returns (bool) {
        emit TransferFrom(sender, receiver, denom, amount);
        return true;
    }

    function _mint(
        address account,
        string memory denom,
        uint256 amount
    ) internal override returns (bool) {
        emit Mint(account, denom, amount);
        return true;
    }

    function _burn(
        address account,
        string memory denom,
        uint256 amount
    ) internal override returns (bool) {
        emit Burn(account, denom, amount);
        return true;
    }
}
