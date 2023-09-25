// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./ICS20TransferERC20.sol";
import "../../core/25-handler/IBCHandler.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// An ICS20 implementation that maps sink denoms to administrator designated ERC20 contracts.
//
// Source denom is interpreted as ERC20 contract address in hex with the 0x prefix.
contract ICS20TransferERC20Allowlist is ICS20TransferERC20, AccessControl {
    constructor(IBCHandler ibcHandler_) ICS20TransferERC20(ibcHandler_) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setDenomTokenContract(string calldata denom, ERC20PresetMinterPauser tokenContract) onlyRole(DEFAULT_ADMIN_ROLE) external {
        require(tokenContract.hasRole(tokenContract.MINTER_ROLE(), address(this)));
        denomTokenContract[denom] = tokenContract;
    }

    function _mint(address account, string memory denom, uint256 amount) internal override returns (bool) {
        if (address(denomTokenContract[denom]) == address(0)) {
            return false;
        }
        try denomTokenContract[denom].mint(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}

// Make external wrappers for testing.
contract ICS20TransferERC20AllowlistTest is ICS20TransferERC20Allowlist {
    constructor(IBCHandler ibcHandler_) ICS20TransferERC20Allowlist(ibcHandler_) {
    }

    function transferFrom(address sender, address receiver, string memory denom, uint256 amount) external {
        require(_transferFrom(sender, receiver, denom, amount));
    }

    function transferFromShouldFail(address sender, address receiver, string memory denom, uint256 amount) external {
        require(!_transferFrom(sender, receiver, denom, amount));
    }

    function mint(address account, string memory denom, uint256 amount) external {
        require(_mint(account, denom, amount));
    }

    function mintShouldFail(address account, string memory denom, uint256 amount) external {
        require(!_mint(account, denom, amount));
    }

    function burn(address account, string memory denom, uint256 amount) external {
        require(_burn(account, denom, amount));
    }

    function burnShouldFail(address account, string memory denom, uint256 amount) external {
        require(!_burn(account, denom, amount));
    }
}
