// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../24-host/IBCStore.sol";
import "../../proto/CellEmitter.sol";

abstract contract CellEmitterHandler is IBCStore {
    event RegisterCellEmitterFilter(CellEmitter.Filter filter);
    event RemoveCellEmitterFilter(CellEmitter.Filter filter);

    function registerCellEmitterFilter(CellEmitter.Filter calldata filter) external returns (bool) {
        uint index = emitterFilters.length;
        for (uint256 i = 0; i < emitterFilters.length; i++) {
            CellEmitter.Filter memory filter_ = emitterFilters[i];
            if (CellEmitter.eq(filter, filter_)) {
                index = i;
                break;
            }
        }
        if (index == emitterFilters.length) {
            return false;
        }
        emitterFilters.push(filter);
        emit RegisterCellEmitterFilter(filter);
        return true;
    }

    function removeCellEmitterFilter(CellEmitter.Filter calldata filter) external returns (bool) {
        uint index = emitterFilters.length;
        for (uint256 i = 0; i < emitterFilters.length; i++) {
            CellEmitter.Filter memory filter_ = emitterFilters[i];
            if (CellEmitter.eq(filter, filter_)) {
                index = i;
                break;
            }
        }
        if (index == emitterFilters.length) {
            return false;
        }
        emitterFilters[index] = emitterFilters[emitterFilters.length-1];
        emitterFilters.pop();
        emit RemoveCellEmitterFilter(filter);
        return true;
    }

    function getCellEmitterFilters() external view returns (CellEmitter.Filter[] memory) {
        return emitterFilters;
    }
}
