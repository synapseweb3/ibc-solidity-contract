// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./CkbProof.sol";

// counterpart for test case verifyTestProof to CkbLightClient::getHeader
function getTestHeader() pure returns (CKBHeader memory) {
    CKBHeader memory ckbHeader = CKBHeader({
        version: 0,
        compactTarget: 0,
        timestamp: 0,
        number: 0,
        epoch: 0,
        parentHash: bytes32(0),
        transactionsRoot: 0x7c57536c95df426f5477c344f8f949e4dfd25443d6f586b4f350ae3e4b870433,
        proposalsHash: bytes32(0),
        extraHash: bytes32(0),
        dao: bytes32(0),
        nonce: uint128(0),
        extension: "",
        blockHash: bytes32(0)
    });
    return ckbHeader;
}

library CkbTestProof {
    // !!!must be idenfical to CkbProof verifyProof except using getTestHeader to replace CkbLightClient::getHeader
    function verifyTestProof(
        bytes calldata rlpiEncodedProof,
        bytes memory path,
        bytes calldata value
    ) public view returns (bool) {
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

        CKBHeader memory header = getTestHeader();
        require(
            header.transactionsRoot ==
                0x7c57536c95df426f5477c344f8f949e4dfd25443d6f586b4f350ae3e4b870433,
            "getHeader transactionsRoot wrong"
        );

        // Create the VerifyProofPayload
        VerifyProofPayload memory payload = VerifyProofPayload({
            verifyType: axonObjProof.proofPayload.verifyType,
            transactionsRoot: header.transactionsRoot,
            witnessesRoot: axonObjProof.proofPayload.witnessesRoot,
            rawTransactionsRoot: axonObjProof.proofPayload.rawTransactionsRoot,
            proof: axonObjProof.proofPayload.proof
        });
        // require(false, "after VerifyProofPayload");

        // Verify the proof
        if (!ckbMbtVerify(payload)) {
            return false;
        }
        // require(false, "after ckbMbtVerify");
        // Parse the commitment from the witness
        CommitmentKV[] memory commitments = parseCommitment(
            axonObjProof.ckbTransaction
        );

        // Check if the commitment path/value matches the provided path/value
        return isCommitInCommitments(commitments, path, value);
    }
}