// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

library CellEmitter {
    struct SearchKey {
        Script script;
        ScriptType scriptType;
        ScriptSearchMode scriptSearchMode;
        Filter[] filter;
        bool withData;
        bool groupByTransaction;
    }

    struct Filter {
        Script script;
        uint64[2] scriptLenRange;
        uint64[2] outputDataLenRange;
        uint64[2] outputDataCapacityRange;
    }

    struct Script {
        bytes32 codeHash;
        ScriptHashType hashType;
        bytes args;
    }

    enum ScriptSearchMode {
        Prefix,
        Exact
    }

    enum ScriptType {
        Lock,
        Type
    }

    //enum definition
    // Solidity enum definitions
    enum ScriptHashType {
        Data,
        Type,
        Data1
    }

    function script_eq(
        CellEmitter.Script memory a,
        CellEmitter.Script memory b
    ) internal pure returns (bool) {
        return
            a.codeHash == b.codeHash &&
            a.hashType == b.hashType &&
            keccak256(a.args) == keccak256(b.args);
    }

    function filter_eq(
        CellEmitter.Filter memory a,
        CellEmitter.Filter memory b
    ) internal pure returns (bool) {
        return
            script_eq(a.script, b.script) &&
            a.scriptLenRange[0] == b.scriptLenRange[0] &&
            a.scriptLenRange[1] == b.scriptLenRange[1] &&
            a.outputDataLenRange[0] == b.outputDataLenRange[0] &&
            a.outputDataLenRange[1] == b.outputDataLenRange[1] &&
            a.outputDataCapacityRange[0] == b.outputDataCapacityRange[0] &&
            a.outputDataCapacityRange[1] == b.outputDataCapacityRange[1];
    }

    function eq(
        CellEmitter.SearchKey memory a,
        CellEmitter.SearchKey memory b
    ) internal pure returns (bool) {
        return
            script_eq(a.script, b.script) &&
            a.scriptType == b.scriptType &&
            a.scriptSearchMode == b.scriptSearchMode &&
            filter_eq(a.filter[0], b.filter[0]) &&
            a.withData == b.withData &&
            a.groupByTransaction == b.groupByTransaction;
    }
}
