// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./ICS20Transfer.sol";
import "../../core/25-handler/IBCHandler.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// An ICS20 implementation that maps sink denoms to ERC20 contracts that's deployed and managed by this contract.
//
// Source denom is interpreted as ERC20 contract address in hex with the 0x prefix.
contract ICS20TransferERC20 is ICS20Transfer {
    // Map sink denom to ERC20.
    mapping(string => ERC20PresetMinterPauser) public denomTokenContract;

    constructor(IBCHandler ibcHandler_) ICS20Transfer(ibcHandler_) {
    }

    function _transferFrom(address sender, address receiver, string memory denom, uint256 amount)
        internal
        override
        returns (bool)
    {
        IERC20 tokenContract = IERC20(parseAddr(denom));
        // transferFrom returns a bool but it may also revert.
        try tokenContract.transferFrom(sender, receiver, amount) returns (bool succeeded) {
            return succeeded;
        } catch (bytes memory) {
            return false;
        }
    }

    function _mint(address account, string memory denom, uint256 amount) internal override returns (bool) {
        // Deploy an ERC20 contract for each (sink zone) denom seen.
        if (address(denomTokenContract[denom]) == address(0)) {
            string memory name = string.concat("IBC/", hexEncode(abi.encodePacked(sha256(bytes(denom)))));
            denomTokenContract[denom] = new ERC20PresetMinterPauser(name, "");
        }
        denomTokenContract[denom].mint(account, amount);
        return true;
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

    function hexEncode(bytes memory buffer) internal pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789ABCDEF";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(converted);
    }

    // a copy from https://github.com/provable-things/ethereum-api/blob/161552ebd4f77090d86482cff8c863cf903c6f5f/oraclizeAPI_0.6.sol
    function parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint256 i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
}

// Make external wrappers for testing.
contract ICS20TransferERC20Test is ICS20TransferERC20 {
    constructor(IBCHandler ibcHandler_) ICS20TransferERC20(ibcHandler_) {
    }

    function mint(address account, string memory denom, uint256 amount) external {
        require(_mint(account, denom, amount));
    }
}
