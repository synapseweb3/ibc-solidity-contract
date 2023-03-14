// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./State.sol";

library IBCHeight {
    function toUint128(Height memory self) internal pure returns (uint128) {
        return (uint128(self.revisionNumber) << 64) | uint128(self.revisionHeight);
    }

    function isZero(Height memory self) internal pure returns (bool) {
        return self.revisionNumber == 0 && self.revisionHeight == 0;
    }

    function lt(Height memory self, Height memory other) internal pure returns (bool) {
        return
            self.revisionNumber < other.revisionNumber ||
            (self.revisionNumber == other.revisionNumber && self.revisionHeight < other.revisionHeight);
    }

    function lte(Height memory self, Height memory other) internal pure returns (bool) {
        return
            self.revisionNumber < other.revisionNumber ||
            (self.revisionNumber == other.revisionNumber && self.revisionHeight <= other.revisionHeight);
    }

    function eq(Height memory self, Height memory other) internal pure returns (bool) {
        return self.revisionNumber == other.revisionNumber && self.revisionHeight == other.revisionHeight;
    }

    function gt(Height memory self, Height memory other) internal pure returns (bool) {
        return
            self.revisionNumber > other.revisionNumber ||
            (self.revisionNumber == other.revisionNumber && self.revisionHeight > other.revisionHeight);
    }

    function gte(Height memory self, Height memory other) internal pure returns (bool) {
        return
            self.revisionNumber > other.revisionNumber ||
            (self.revisionNumber == other.revisionNumber && self.revisionHeight >= other.revisionHeight);
    }
}
