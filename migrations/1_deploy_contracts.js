const IBCPacket = artifacts.require('IBCPacket');
const IBCConnection = artifacts.require('IBCConnection');
const IBCChannel = artifacts.require('IBCChannelHandshake');
const IBCClient = artifacts.require('IBCClient');
// const IBCHandler = artifacts.require('OwnableIBCHandler');
const IBCTestHandler = artifacts.require('IBCTestHandler');
const MockClient = artifacts.require('MockClient');
const MockModule = artifacts.require('MockModule');

module.exports = async function (deployer, network) {
  console.log("deploy contracts for network " + network)
  await deployer.deploy(IBCPacket);
  await deployer.deploy(IBCConnection);
  await deployer.deploy(IBCChannel);
  await deployer.deploy(IBCClient);

  const ibcClient = await IBCClient.deployed();
  const ibcPacket = await IBCPacket.deployed();
  const ibcConnection = await IBCConnection.deployed();
  const ibcChannel = await IBCChannel.deployed();
  await deployer.deploy(IBCTestHandler, ibcClient.address, ibcConnection.address, ibcChannel.address, ibcPacket.address);
  if (network == "development") {
    const ibcTestHandler = await IBCTestHandler.deployed();
    await deployer.deploy(MockClient);
    await ibcTestHandler.registerClient("MockClient", MockClient.address);
    await deployer.deploy(MockModule);
  }
  console.log("done deploying contracts")
};
