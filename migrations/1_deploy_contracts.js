const IBCPacket = artifacts.require("IBCPacket");
const IBCConnection = artifacts.require("IBCConnection");
const IBCChannel = artifacts.require("IBCChannelHandshake");
const IBCClient = artifacts.require("IBCClient");
const MockClient = artifacts.require("MockClient");
const MockModule = artifacts.require("MockModule");
const CkbClient = artifacts.require("CkbClient");
const Molecule = artifacts.require("Molecule");
const CkbProof = artifacts.require("CkbProof");
const CkbLightClient = artifacts.require("CkbLightClient");

module.exports = async function (deployer, network) {
  console.log("Deploy contracts for network", network);

  // 1. deploy contracts
  await deployer.deploy(IBCPacket);
  await deployer.deploy(IBCConnection);
  await deployer.deploy(IBCChannel);
  await deployer.deploy(IBCClient);
  await deployer.deploy(MockClient);
  await deployer.deploy(MockModule);

  const molecule = await Molecule.new();
  const ckbLightClient = await CkbLightClient.new();
  CkbProof.link(molecule);
  CkbProof.link(ckbLightClient);
  const ckbProof = await CkbProof.new();
  CkbClient.link(ckbProof);
  await deployer.deploy(CkbClient);

  const ibcClient = await IBCClient.deployed();
  const ibcPacket = await IBCPacket.deployed();
  const ibcConnection = await IBCConnection.deployed();
  const ibcChannel = await IBCChannel.deployed();
  const mockClient = await MockClient.deployed();
  const ckbClient = await CkbClient.deployed();

  // 2. deploy IBCMockHandler
  let IBCHandler = undefined;

  if (network == "axon") {
    // The contract size of OwnableIBCHandler is too large to deploy on a normal EVM chain.
    // see https://github.com/synapseweb3/ibc-solidity-contract/issues/9
    IBCHandler = artifacts.require("OwnableIBCHandler");

  } else {
    IBCHandler = artifacts.require("IBCMockHandler");
  }
  await deployer.deploy(
    IBCHandler,
    ibcClient.address,
    ibcConnection.address,
    ibcChannel.address,
    ibcPacket.address
  );
  ibcHandler = await IBCHandler.deployed();

  // 3. register Client
  const axonClientType = "07-axon";
  await ibcHandler.registerClient(axonClientType, mockClient.address);
  const ckbClientType = "07-ckb4ibc";
  await ibcHandler.registerClient(ckbClientType, ckbClient.address);

  // 4. register MockTransfer Module
  const MockTransfer = artifacts.require("MockTransfer");
  await deployer.deploy(MockTransfer, ibcHandler.address);
  const mockTransfer = await MockTransfer.deployed();
  await ibcHandler.bindPort("port-0", mockTransfer.address);
  console.log("Registered MockTransfer Module: port-0");

  // 5. register ICS20TransferERC20 Module
  const ICS20TransferERC20 = artifacts.require("ICS20TransferERC20");
  await deployer.deploy(ICS20TransferERC20, ibcHandler.address);
  const ics20Transfer = await ICS20TransferERC20.deployed();
  await ibcHandler.bindPort("transfer", ics20Transfer.address);
  console.log("Registered ICS20TransferERC20 Module: transfer");

  // 6. print OwnableIBCHandler and ICS20TransferERC20 addresses for CI parsing
  console.log("Done Deployment OwnableIBCHandler at " + ibcHandler.address);
  console.log("Done Deployment ICS20TransferERC20 at " + ics20Transfer.address);
};
