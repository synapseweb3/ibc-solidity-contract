const IBCPacket = artifacts.require("IBCPacket");
const IBCConnection = artifacts.require("IBCConnection");
const IBCChannel = artifacts.require("IBCChannelHandshake");
const IBCClient = artifacts.require("IBCClient");
const IBCHandler = artifacts.require("OwnableIBCHandler");

require("dotenv").config({
  path: `${__dirname}/../.env`,
});
const ethers = require("ethers");
const mnemonic = "test test test test test test test test test test test junk";

module.exports = async function (deployer, network) {
  if (network == "development") {
    console.log("Deploy contracts for network " + network);
    const IBCMockHandler = artifacts.require("IBCMockHandler");
    const MockClient = artifacts.require("MockClient");
    const MockModule = artifacts.require("MockModule");

    await deployer.deploy(IBCPacket);
    await deployer.deploy(IBCConnection);
    await deployer.deploy(IBCChannel);
    await deployer.deploy(IBCClient);

    const ibcClient = await IBCClient.deployed();
    const ibcPacket = await IBCPacket.deployed();
    const ibcConnection = await IBCConnection.deployed();
    const ibcChannel = await IBCChannel.deployed();
    await deployer.deploy(
      IBCMockHandler,
      ibcClient.address,
      ibcConnection.address,
      ibcChannel.address,
      ibcPacket.address
    );
    const ibcTestHandler = await IBCMockHandler.deployed();
    await deployer.deploy(MockClient);
    await ibcTestHandler.registerClient("MockClient", MockClient.address);
    await deployer.deploy(MockModule);
    console.log("Done deploying contracts");
  } else {
    // production
    const packetAddress = await deployContract("IBCPacket");
    const connectionAddress = await deployContract("IBCConnection");
    const channelAddress = await deployContract("IBCChannelHandshake");
    const clientAddress = await deployContract("IBCClient");
    const mockModuleAddress = await deployContract("MockModule");
    const ibcAddress = await deployContract(
      "OwnableIBCHandler",
      clientAddress,
      connectionAddress,
      channelAddress,
      packetAddress
    );
    const mockClient = await deployContract("MockClient");
    const ibcHandler = await IBCHandler.at(ibcAddress);

    // Register Client
    const clientType = "AxonClient";
    await ibcHandler.registerClient(clientType, mockClient);
    console.log("Register Axon Client: AxonClient");

    // Create Client
    const msgCreateClient = {
      clientType: clientType,
      consensusState: 1234,
      clientState: 1234,
    };
    const clientId = await ibcHandler.createClient.call(msgCreateClient);
    await ibcHandler.createClient(msgCreateClient);
    console.log("Create Client ID: " + clientId);

    // Register Module (optional, just for the cooperation of test on Axon endpoint)
    await ibcHandler.bindPort("mock-port-0", mockModuleAddress);
    console.log("Register Mock Module: mock-port-0");
  }
};

async function deployContract(contractName, ...args) {
  const provider = new ethers.providers.JsonRpcProvider(process.env.AXON_RPC_URL);
  const signer = new ethers.Wallet.fromMnemonic(mnemonic).connect(provider);
  const contract = artifacts.require(contractName); // load contract from json
  const abi = new ethers.utils.Interface(contract.abi);
  const factory = new ethers.ContractFactory(abi, contract.bytecode, signer);
  const contractInstance = await factory.deploy(...args);
  console.log("Done Deployment " + contractName + " at " + contractInstance.address);
  return contractInstance.address;
}
