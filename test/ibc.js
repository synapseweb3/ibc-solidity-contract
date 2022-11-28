const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, assert } = require("chai");
const { upgrades, ethers } = require("hardhat");

function epoch_height_bytes32(epoch, height) {
  function intToBytes(x, i) {
    var bytes = [];
    do {
      bytes[--i] = x & (255);
      x = x>>8;
    } while (i);
    return bytes;
  }
  const epoch_bytes = intToBytes(epoch, 16);
  const height_bytes = intToBytes(height, 16);
  const bytes32 = epoch_bytes.concat(height_bytes);
  assert(bytes32.length == 32);
  return bytes32;
}

function hexToBytes(hex) {
  let bytes = [];
  for (let c = 0; c < hex.length; c += 2) {
    bytes.push(parseInt(hex.substr(c, 2), 16));
  }
  return bytes;
}

describe("IBC CKB", function () {
  const IBC_RELAYER = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("IBC_RELAYER"));

  const msg_client_create = {
    client: {
      chain_id: "5",
      client_type: 4,
      latest_height: epoch_height_bytes32(333, 101),
      frozen_height: epoch_height_bytes32(0, 0),
      trusting_period: 100000,
      max_clock_drift: 100000,
      extra_payload: []
    },
    consensus: {
      timestamp: Date.now(),
      commitment_root: hexToBytes("63b9fe46a9217a85203fc0cd7b67f3238ec93889d21fefb7cf11d40a1c3ddd9c"),
      extra_payload: []
    }
  };

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploy() {
    // Contracts are deployed using the first signer/account by default
    const [owner, relayer, ...wallets] = await ethers.getSigners();

    const IBC = await ethers.getContractFactory("IBC");
    const IBC_PROXY = await upgrades.deployProxy(IBC, [], { initializer: "construct" });
    await IBC_PROXY.deployed();
    
    const CKB = await ethers.getContractFactory("CkbLightclient");
    const CKB_PROXY = await upgrades.deployProxy(CKB, [IBC_PROXY.address], { initializer: "construct" });
    await CKB_PROXY.deployed();

    await IBC_PROXY.set_light_client(4, CKB_PROXY.address);
    await IBC_PROXY.grantRole(IBC_RELAYER, relayer.address);

    return { contract: IBC_PROXY, relayer, owner, wallets };
  }

  describe("Protocol Client", function () {
    it("Should emit 'CreateClient' after calling client_create()", async function () {
      const { contract, relayer } = await loadFixture(deploy);

      await expect(contract.connect(relayer).client_create(msg_client_create))
        .emit(contract, "CreateClient")
        .withArgs(
          "CKB-5-1",
          4,
          anyValue
        );
    });

    it("Should emit 'UpdateClient' after calling client_update()", async function () {
      let { contract, relayer } = await loadFixture(deploy);

      const msg_client_update = {
        client_id: "CKB-5-1",
        header_bytes: []
      };

      contract = contract.connect(relayer);
      await contract.client_create(msg_client_create);
      await expect(contract.client_update(msg_client_update))
        .emit(contract, "UpdateClient")
        .withArgs(
          "CKB-5-1",
          4,
          anyValue
        );
    });
  });
});
