// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

library IBCUtil {
    function check_delegatecall(
        bool success,
        bytes memory result,
        string memory prefix
    ) internal pure {
        if (!success) {
            if (result.length == 0) {
                revert(string.concat(prefix, " delegatecall error"));
            }
            assembly {
                revert(add(32, result), mload(result))
            }
            // assembly {
            //     result := add(result, 0x04)
            // }
            // revert(abi.decode(result, (string)));
        }
    }
}
