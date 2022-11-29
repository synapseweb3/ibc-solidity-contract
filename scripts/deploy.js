// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const IBC_RELAYER = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("IBC_RELAYER"));

async function main() {
  const [_, relayer] = await ethers.getSigners();

  const IBC = await ethers.getContractFactory("IBC");
  const IBC_PROXY = await upgrades.deployProxy(IBC, [], { initializer: "construct" });
  await IBC_PROXY.deployed();
  
  const CKB = await ethers.getContractFactory("CkbLightclient");
  const CKB_PROXY = await upgrades.deployProxy(CKB, [IBC_PROXY.address], { initializer: "construct" });
  await CKB_PROXY.deployed();

  await IBC_PROXY.set_light_client(4, CKB_PROXY.address);
  await IBC_PROXY.grantRole(IBC_RELAYER, relayer.address);

  console.log(
    `IBC contract deployed at ${IBC_PROXY.address} with CKBLightclient setup, the relayer is ${relayer.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
