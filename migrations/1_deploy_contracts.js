const IBCPacket = artifacts.require("IBCPacket");
const IBCConnection = artifacts.require("IBCConnection");
const IBCChannel = artifacts.require("IBCChannelHandshake");
const IBCClient = artifacts.require("IBCClient");
const IBCOwnableHandler = artifacts.require("OwnableIBCHandler");
const IBCMockHandler = artifacts.require("IBCMockHandler");
const MockClient = artifacts.require("MockClient");
const MockModule = artifacts.require("MockModule");

module.exports = async function (deployer, network) {
  console.log("Deploy contracts for network", network);

  // 1. deploy contracts
  await deployer.deploy(IBCPacket);
  await deployer.deploy(IBCConnection);
  await deployer.deploy(IBCChannel);
  await deployer.deploy(IBCClient);
  await deployer.deploy(MockClient);
  await deployer.deploy(MockModule);

  const ibcClient = await IBCClient.deployed();
  const ibcPacket = await IBCPacket.deployed();
  const ibcConnection = await IBCConnection.deployed();
  const ibcChannel = await IBCChannel.deployed();
  const mockClient = await MockClient.deployed();

  let ibcHandler = undefined;
  if (network == "development") {
    // 2. deploy IBCMockHandler

    await deployer.deploy(
      IBCMockHandler,
      ibcClient.address,
      ibcConnection.address,
      ibcChannel.address,
      ibcPacket.address
    );
  } else {
    // 2. deploy OwnableIBCHandler
    await deployer.deploy(
      IBCOwnableHandler,
      ibcClient.address,
      ibcConnection.address,
      ibcChannel.address,
      ibcPacket.address
    );
  }
  ibcHandler = await IBCMockHandler.deployed();

  // 3. register Client
  const axonClientType = "07-axon";
  await ibcHandler.registerClient(axonClientType, mockClient.address);
  const ckbClientType = "07-ckb4ibc";
  await ibcHandler.registerClient(ckbClientType, mockClient.address);

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
};
