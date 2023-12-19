const Molecule = artifacts.require("Molecule");
const CkbTestProof = artifacts.require("CkbTestProof");

const fs = require('fs');
const proof_path = require('path');

contract("verifyTestProof", (accounts) => {
  it("test verifyMembership", async () => {
    const molecule = await Molecule.new();
    console.log("molecule deployed on ", molecule.address);
    await CkbTestProof.link(molecule);

    const ckbTestProof = await CkbTestProof.new();
    console.log("CkbTestProof deployed on ", ckbTestProof.address);

    console.log("rlpEncodedProof");
    const filePath = proof_path.join(__dirname, './7c57_rlp.txt');
    const hexString = fs.readFileSync(filePath, 'utf8');
    console.log("hexString len ", hexString.length);
    const rlpEncodedProof = web3.utils.hexToBytes(hexString);
    console.log("rlpEncodedProof len ", rlpEncodedProof.length);

    const path = "commitments/ports/ccdefc1fc781b8c1a9a946dfdeeb32829ef2f86e47e8e4d69f6e5bbbb960f42c/channels/channel-0/sequences/1";
    const value = "0xec577607291e6c583bdf479ab7f8b59f851419121e3d116befeeeb0f1b0a4f87";
    const pathBytes = Buffer.from(path);
    const valueBytes = Buffer.from(value.slice(2), 'hex');  // remove the "0x" prefix and convert from hexadecimal

    const result = await ckbTestProof.verifyTestProof(rlpEncodedProof, pathBytes, valueBytes);
    assert.equal(result, true, "The proof verification did not return the expected result");
  });
});
