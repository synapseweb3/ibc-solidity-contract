// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../utils/Molecule.sol";
import "solidity-rlp/contracts/RLPReader.sol";

using Molecule for bytes;
using RLPReader for bytes;
using RLPReader for RLPReader.RLPItem;

struct Proof {
    uint32[] indices;
    bytes32[] lemmas;
    bytes32[] leaves;
}

struct VerifyProofPayload {
    uint8 verifyType;
    bytes32 transactionsRoot;
    bytes32 witnessesRoot;
    bytes32 rawTransactionsRoot;
    Proof proof;
}

struct AxonObjectProof {
    bytes ckbTransaction;
    bytes32 blockHash;
    VerifyProofPayload proofPayload;
}

struct CKBHeader {
    uint32 version;
    uint32 compactTarget;
    uint64 timestamp;
    uint64 number;
    uint64 epoch;
    bytes32 parentHash;
    bytes32 transactionsRoot;
    bytes32 proposalsHash;
    bytes32 extraHash;
    bytes32 dao;
    uint128 nonce;
    bytes extension;
    bytes32 blockHash;
}

// Define the CommitmentKV struct
struct CommitmentKV {
    uint256 key;
    uint256 value;
}

// Define the Envelope struct
struct Envelope {
    // MsgType msg_type; ignore msg_type now
    CommitmentKV[] commitments;
    bytes content;
}

function getHeader(bytes32 blockHash) view returns (CKBHeader memory) {
    // axon_precompile_address(0x02)
    address get_header_addr = address(0x0102);
    (bool isSuccess, bytes memory res) = get_header_addr.staticcall(
        abi.encode(blockHash)
    );
    require(isSuccess, "getHeader");
    return abi.decode(res, (CKBHeader));
}

// Define ckb blake2b
function blake2b(bytes memory data) view returns (bytes32) {
    // axon_precompile_address(0x06)
    address blake2b_addr = address(0x0106);
    (bool isSuccess, bytes memory res) = blake2b_addr.staticcall(data);
    require(isSuccess, "blake2b");
    return abi.decode(res, (bytes32));
}

function ckbMbtVerify(VerifyProofPayload memory payload) view returns (bool) {
    // axon_precompile_address(0x07)
    address ckb_mbt_addr = address(0x0107);
    (bool isSuccess, bytes memory res) = ckb_mbt_addr.staticcall(
        abi.encode(payload)
    );
    require(isSuccess, "ckbMbtVerify");
    return uint8(res[0]) == 1;
}

function calculateHashes(
    bytes memory ckbTransaction
) view returns (bytes32 transactionHash, bytes32 witnessHash) {
    // Calculate the hashes here
    (uint256 offset, uint256 size) = ckbTransaction.readCKBTxRaw();
    bytes memory raw_tx = new bytes(size);
    for (uint i = 0; i < size; i++) {
        raw_tx[i] = ckbTransaction[i + offset];
    }

    return (blake2b(raw_tx), blake2b(ckbTransaction));
}

function decodeRlpEnvelope(
    bytes memory rlpEncodedData
) pure returns (Envelope memory) {
    RLPReader.RLPItem[] memory ls = rlpEncodedData.toRlpItem().toList();

    // Decode the commitments
    RLPReader.RLPItem[] memory commitmentsRlp = ls[1].toList();
    CommitmentKV[] memory commitments = new CommitmentKV[](
        commitmentsRlp.length
    );
    for (uint i = 0; i < commitmentsRlp.length; i++) {
        RLPReader.RLPItem[] memory kvRlp = commitmentsRlp[i].toList();
        commitments[i] = CommitmentKV(kvRlp[0].toUint(), kvRlp[1].toUint());
    }

    // Decode the content
    bytes memory content = ls[2].toBytes();

    // Return the decoded Envelope
    return Envelope(commitments, content);
}

function parseCommitment(
    bytes memory ckbTransaction
) pure returns (CommitmentKV[] memory) {
    uint256 witness_count = ckbTransaction.readCKBTxWitnessCount();
    uint8 output_type_index = 2;
    (uint256 offset, uint256 size) = ckbTransaction.readCKBTxWitness(
        uint8(witness_count - 1),
        output_type_index
    );
    bytes memory output_type_bytes = new bytes(size);
    for (uint i = 0; i < size; i++) {
        output_type_bytes[i] = ckbTransaction[i + offset];
    }
    Envelope memory envelope = decodeRlpEnvelope(output_type_bytes);
    return envelope.commitments;
}

function verifyHashExist(
    bytes32[] memory leaves,
    bytes32 witnessHash
) pure returns (bool) {
    bool isInLeaves = false;
    for (uint i = 0; i < leaves.length; i++) {
        if (leaves[i] == witnessHash) {
            isInLeaves = true;
            break;
        }
    }

    return isInLeaves;
}

function isCommitInCommitments(
    CommitmentKV[] memory commitments,
    bytes memory key,
    bytes calldata value
) pure returns (bool) {
    uint256 keyHash = uint256(keccak256(key));
    uint256 valueHash = uint256(keccak256(value));
    for (uint i = 0; i < commitments.length; i++) {
        if (
            commitments[i].key == keyHash && commitments[i].value == valueHash
        ) {
            return true;
        }
    }
    return false;
}

function decodeProof(
    RLPReader.RLPItem[] memory items
) pure returns (Proof memory) {
    require(items.length == 3, "Invalid proof length");

    Proof memory proof;

    // Decode indices
    RLPReader.RLPItem[] memory indicesItems = RLPReader.toList(items[0]);
    proof.indices = new uint32[](indicesItems.length);
    for (uint i = 0; i < indicesItems.length; i++) {
        proof.indices[i] = uint32(RLPReader.toUint(indicesItems[i]));
    }

    // Decode lemmas
    RLPReader.RLPItem[] memory lemmasItems = RLPReader.toList(items[1]);
    proof.lemmas = new bytes32[](lemmasItems.length);
    for (uint i = 0; i < lemmasItems.length; i++) {
        proof.lemmas[i] = bytes32(RLPReader.toBytes(lemmasItems[i]));
    }

    // Decode leaves
    RLPReader.RLPItem[] memory leavesItems = RLPReader.toList(items[2]);
    proof.leaves = new bytes32[](leavesItems.length);
    for (uint i = 0; i < leavesItems.length; i++) {
        proof.leaves[i] = bytes32(RLPReader.toBytes(leavesItems[i]));
    }

    return proof;
}

function decodeAxonObjectProof(
    bytes memory rlpData
) pure returns (AxonObjectProof memory) {
    RLPReader.RLPItem[] memory items = RLPReader.toList(
        RLPReader.toRlpItem(rlpData)
    );
    require(items.length == 3, "Invalid RLP data length");

    AxonObjectProof memory axonProof;
    axonProof.ckbTransaction = RLPReader.toBytes(items[0]);
    axonProof.blockHash = bytes32(RLPReader.toBytes(items[1]));

    RLPReader.RLPItem[] memory payloadItems = RLPReader.toList(items[2]);
    require(payloadItems.length == 5, "Invalid payload length");

    axonProof.proofPayload.verifyType = uint8(
        RLPReader.toUint(payloadItems[0])
    );
    axonProof.proofPayload.transactionsRoot = bytes32(
        RLPReader.toBytes(payloadItems[1])
    );
    axonProof.proofPayload.witnessesRoot = bytes32(
        RLPReader.toBytes(payloadItems[2])
    );
    axonProof.proofPayload.rawTransactionsRoot = bytes32(
        RLPReader.toBytes(payloadItems[3])
    );

    require(payloadItems[4].isList(), "Invalid payload proof");
    axonProof.proofPayload.proof = decodeProof(
        RLPReader.toList(payloadItems[4])
    );

    return axonProof;
}

library CkbProof {
    event Log(string message);

    function verifyProof(
        bytes calldata rlpiEncodedProof,
        bytes memory path,
        bytes calldata value
    ) internal view returns (bool) {
        // Parse the proof from the abi encoded data
        AxonObjectProof memory axonObjProof = decodeAxonObjectProof(
            rlpiEncodedProof
        );

        // Calculate the transaction hash and witness hash
        (, bytes32 witnessHash) = calculateHashes(axonObjProof.ckbTransaction);

        // Check if the witness hash is in the leaves
        if (
            !verifyHashExist(
                axonObjProof.proofPayload.proof.leaves,
                witnessHash
            )
        ) {
            return false;
        }

        // Get the CKB header
        CKBHeader memory header = getHeader(axonObjProof.blockHash);

        // Create the VerifyProofPayload
        VerifyProofPayload memory payload = VerifyProofPayload({
            verifyType: axonObjProof.proofPayload.verifyType,
            transactionsRoot: header.transactionsRoot,
            witnessesRoot: axonObjProof.proofPayload.witnessesRoot,
            rawTransactionsRoot: axonObjProof.proofPayload.rawTransactionsRoot,
            proof: axonObjProof.proofPayload.proof
        });

        // Verify the proof
        if (!ckbMbtVerify(payload)) {
            return false;
        }

        // Parse the commitment from the witness
        CommitmentKV[] memory commitments = parseCommitment(
            axonObjProof.ckbTransaction
        );

        // Check if the commitment path/value matches the provided path/value
        require(isCommitInCommitments(commitments, path, value), "commitment mismatch");

        return true;
    }
}
