// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../../proto/CellEmitter.sol";

abstract contract CellEmitterHandler {
    event RegisterCellEmitterFilter(CellEmitter.SearchKey filter);
    event RemoveCellEmitterFilter(CellEmitter.SearchKey filter);

    function registerCellEmitterFilter(
        CellEmitter.SearchKey calldata filter
    ) external {
        emit RegisterCellEmitterFilter(filter);
    }

    function removeCellEmitterFilter(
        CellEmitter.SearchKey calldata filter
    ) external {
        emit RemoveCellEmitterFilter(filter);
    }

    // FIXME: add authticate attribute
    function upload_ckb_cell(CellEmitter.Cell calldata cell) external {
        // TODO: call system contract
    }

    // FIXME: add authticate attribute
    function upload_ckb_header(CellEmitter.Header calldata header) external {
        // TODO: call system contract
    }
}
