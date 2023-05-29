// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

library CellEmitter {
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

  //enum definition
  // Solidity enum definitions
  enum ScriptHashType {
    Data,
    Type,
    Data1
  }

  // Solidity enum encoder
  function encodeScriptHashType(ScriptHashType x) internal pure returns (int32) {

    if (x == ScriptHashType.Data) {
      return 0;
    }

    if (x == ScriptHashType.Type) {
      return 1;
    }

    if (x == ScriptHashType.Data1) {
      return 2;
    }

    revert();
  }

  // Solidity enum decoder
  function decodeScriptHashType(int64 x) internal pure returns (ScriptHashType) {

    if (x == 0) {
      return ScriptHashType.Data;
    }

    if (x == 1) {
      return ScriptHashType.Type;
    }

    if (x == 2) {
      return ScriptHashType.Data1;
    }

    revert();
  }

  function eq(CellEmitter.Filter memory a, CellEmitter.Filter memory b) internal pure returns (bool) {
  return a.script.codeHash == b.script.codeHash
      && a.script.hashType == b.script.hashType
      && keccak256(a.script.args) == keccak256(b.script.args)
      && a.scriptLenRange[0] == b.scriptLenRange[0]
      && a.scriptLenRange[1] == b.scriptLenRange[1]
      && a.outputDataLenRange[0] == b.outputDataLenRange[0]
      && a.outputDataLenRange[1] == b.outputDataLenRange[1]
      && a.outputDataCapacityRange[0] == b.outputDataCapacityRange[0]
      && a.outputDataCapacityRange[1] == b.outputDataCapacityRange[1];
  }
}
