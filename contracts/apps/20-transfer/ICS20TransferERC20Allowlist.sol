// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./ICS20Transfer.sol";
import "../../core/25-handler/IBCHandler.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// An ICS20 implementation that maps denoms to administrator designated ERC20 contracts.
contract ICS20TransferERC20Allowlist is ICS20Transfer, AccessControl {
    // Map denom to ERC20.
    mapping(string => ERC20PresetMinterPauser) public denomTokenContract;

    constructor(IBCHandler ibcHandler_) ICS20Transfer(ibcHandler_) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setDenomTokenContract(string calldata denom, ERC20PresetMinterPauser tokenContract) onlyRole(DEFAULT_ADMIN_ROLE) external {
        require(tokenContract.hasRole(tokenContract.MINTER_ROLE(), address(this)));
        denomTokenContract[denom] = tokenContract;
    }

    function _transferFrom(address, address, string memory, uint256)
        internal
        override
        pure
        returns (bool)
    {
        // Not supported because we always assume that we are the sink zone and we will only mint/burn.
        return false;
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

    function _burn(address account, string memory denom, uint256 amount) internal override returns (bool) {
        if (address(denomTokenContract[denom]) == address(0)) {
            return false;
        }
        try denomTokenContract[denom].burnFrom(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}

// Make external wrappers of _mint/_burn for testing.
contract ICS20TransferERC20AllowlistTest is ICS20TransferERC20Allowlist {
    constructor(IBCHandler ibcHandler_) ICS20TransferERC20Allowlist(ibcHandler_) {
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
