// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../24-host/IBCStore.sol";

abstract contract CellEmitterHandler is IBCStore {
    event RegisterCellEmitterFilter(string filter);
    event RemoveCellEmitterFilter(string filter);

    function registerCellEmitterFilter(
        string calldata filter
    ) external returns (bool) {
        uint block_number = emitterFilters[filter];
        if (block_number > 0) {
            return false;
        }
        emitterFilters[filter] = block.number;
        filterKeys.push(filter);
        emit RegisterCellEmitterFilter(filter);
        return true;
    }

    function removeCellEmitterFilter(
        string calldata filter
    ) external returns (bool) {
        uint block_number = emitterFilters[filter];
        if (block_number == 0) {
            return false;
        }
        delete emitterFilters[filter];
        for (uint i = 0; i < filterKeys.length; i++) {
            if (emitterFilters[filterKeys[i]] == 0) {
                filterKeys[i] = filterKeys[filterKeys.length - 1];
                filterKeys.pop();
                break;
            }
        }
        emit RemoveCellEmitterFilter(filter);
        return true;
    }

    function getCellEmitterFilters() external view returns (string[] memory) {
        return filterKeys;
    }
}
