pragma solidity ^0.8.4;

library Molecule {
    // return offset and size of RawTransaction
    function readCKBTxRaw(
        bytes calldata input
    ) public pure returns (uint256 offset, uint256 size) {
        offset = tableOffset(input, 0, 0);
        uint256 endOffset = tableOffset(input, 0, 1);
        require(offset <= endOffset, "endOffset must > offset");
        size = endOffset - offset;
    }

    // return offset and size of WitnessArgs field (the molecule bytes header is trimed)
    function readCKBTxWitnessCount(
        bytes calldata input
    ) public pure returns (uint256 count) {
        uint256 offset = tableOffset(input, 0, 1);
        count = tableFieldsCount(input, offset);
    }

    // return offset and size of WitnessArgs field (the molecule bytes header is trimed)
    function readCKBTxWitness(
        bytes calldata input,
        uint8 witnessIndex,
        uint8 fieldIndex
    ) public pure returns (uint256 offset, uint256 size) {
        require(fieldIndex < 3, "WitnessArgs has only 3 fields");
        // witnesses
        offset = tableOffset(input, 0, 1);
        // witness
        offset += tableOffset(input, offset, witnessIndex);
        // skip bytes length
        offset += 4;
        // check witness args fields
        uint256 fields = tableFieldsCount(input, offset);
        require(fields == 3, "witness args fields is 3");
        // read witness args
        uint256 fieldOffset = tableOffset(input, offset, fieldIndex);
        // calculate field size
        if (fieldIndex == 2) {
            // witness args size
            size = tableTotalSize(input, offset);
            size -= fieldOffset;
        } else {
            // next field offset - current field offset
            size = tableOffset(input, offset, fieldIndex + 1) - fieldOffset;
        }
        offset += fieldOffset;
        // skip molecule bytes length if isn't null
        if (size != 0) {
            require(size >= 4, "Bytes header");
            size -= 4;
            offset += 4;
        }
    }

    function tableOffset(
        bytes calldata input,
        uint256 offset,
        uint256 fieldIndex
    ) public pure returns (uint256 result) {
        require(
            offset + 4 + fieldIndex * 4 <= input.length,
            "Bytes: Out of range"
        );
        assembly {
            let ptr := mload(0x40)
            // skip molecule table size(4)
            offset := add(add(4, offset), mul(fieldIndex, 4))
            calldatacopy(ptr, add(input.offset, offset), 4)
            result := mload(ptr)
        }
        result = reverse(result);
    }

    function tableTotalSize(
        bytes calldata input,
        uint256 offset
    ) public pure returns (uint256 result) {
        require(offset + 4 <= input.length, "Bytes: Out of range");
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, add(input.offset, offset), 4)
            result := mload(ptr)
        }
        result = reverse(result);
    }

    function tableFieldsCount(
        bytes calldata input,
        uint256 offset
    ) public pure returns (uint256 result) {
        uint256 headerEnd = tableOffset(input, offset, 0);
        assembly {
            result := sub(div(headerEnd, 4), 1)
        }
    }

    function reverse(uint256 input) internal pure returns (uint256 v) {
        v = input;

        // swap bytes
        v =
            ((v &
                0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >>
                8) |
            ((v &
                0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) <<
                8);

        // swap 2-byte long pairs
        v =
            ((v &
                0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >>
                16) |
            ((v &
                0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) <<
                16);

        // swap 4-byte long pairs
        v =
            ((v &
                0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >>
                32) |
            ((v &
                0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) <<
                32);

        // swap 8-byte long pairs
        v =
            ((v &
                0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >>
                64) |
            ((v &
                0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) <<
                64);

        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }
}
