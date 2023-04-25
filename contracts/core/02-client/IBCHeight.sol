// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../../proto/Client.sol";

library IBCHeight {
    function toUint128(Height.Data memory self) internal pure returns (uint128) {
        return (uint128(self.revisionNumber) << 64) | uint128(self.revisionHeight);
    }

    function isZero(Height.Data memory self) internal pure returns (bool) {
        return self.revisionNumber == 0 && self.revisionHeight == 0;
    }

    function lt(Height.Data memory self, Height.Data memory other) internal pure returns (bool) {
        return self.revisionNumber < other.revisionNumber
            || (self.revisionNumber == other.revisionNumber && self.revisionHeight < other.revisionHeight);
    }

    function lte(Height.Data memory self, Height.Data memory other) internal pure returns (bool) {
        return self.revisionNumber < other.revisionNumber
            || (self.revisionNumber == other.revisionNumber && self.revisionHeight <= other.revisionHeight);
    }

    function eq(Height.Data memory self, Height.Data memory other) internal pure returns (bool) {
        return self.revisionNumber == other.revisionNumber && self.revisionHeight == other.revisionHeight;
    }

    function gt(Height.Data memory self, Height.Data memory other) internal pure returns (bool) {
        return self.revisionNumber > other.revisionNumber
            || (self.revisionNumber == other.revisionNumber && self.revisionHeight > other.revisionHeight);
    }

    function gte(Height.Data memory self, Height.Data memory other) internal pure returns (bool) {
        return self.revisionNumber > other.revisionNumber
            || (self.revisionNumber == other.revisionNumber && self.revisionHeight >= other.revisionHeight);
    }
}
