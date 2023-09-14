// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./ICS20Transfer.sol";
import "../../core/25-handler/IBCHandler.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// An ICS20 implementation that maps denoms to ERC20.
contract ICS20TransferERC20 is ICS20Transfer, AccessControlEnumerable {
    // ERC20PresetMinterPauser role. Why can't I reference this?
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Map denom to ERC20 contract (ERC20PresetMinterPauser).
    mapping(string => address) public denomTokenContract;

    constructor(IBCHandler ibcHandler_) ICS20Transfer(ibcHandler_) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setDenomTokenContract(string calldata denom, address tokenContract) onlyRole(DEFAULT_ADMIN_ROLE) external {
        require(ERC20PresetMinterPauser(tokenContract).hasRole(MINTER_ROLE, address(this)));
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
        try ERC20PresetMinterPauser(denomTokenContract[denom]).mint(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }

    function _burn(address account, string memory denom, uint256 amount) internal override returns (bool) {
        try ERC20PresetMinterPauser(denomTokenContract[denom]).burnFrom(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}
