const ethers = require("ethers");
const mnemonic = "test test test test test test test test test test test junk";

async function main() {
  // First provider account.
  const mintAddress = process.env.MINT_TO;
  const mintAmount = process.env.MINT_AMOUNT;
  const name = process.env.TOKEN_NAME;
  const symbol = process.env.TOKEN_SYMBOL;

  const IERC20 = artifacts.require("IERC20");
  const tokenAddress = await deployContract("SimpleToken", name, symbol, mintAmount);
  let token = new IERC20(tokenAddress);
  await token.transfer(mintAddress, mintAmount);
  console.log("mint token to ", mintAddress, mintAmount);
}

module.exports = (callback) => {
  main().then(callback).catch(e => {
    console.log("Error:", e.message, e);
    callback();
  });
};

function timeout(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function deployContract(contractName, ...args) {
  const provider = new ethers.providers.JsonRpcProvider(process.env.AXON_HTTP_RPC_URL);
  const signer = new ethers.Wallet.fromMnemonic(mnemonic).connect(provider);
  const contract = artifacts.require(contractName); // load contract from json
  const abi = new ethers.utils.Interface(contract.abi);
  const factory = new ethers.ContractFactory(abi, contract.bytecode, signer);
  const contractInstance = await factory.deploy(...args);

  // wait getCode
  let code = await provider.getCode(contractInstance.address);
  while (code == '0x') {
    console.log("failed to fetch code of ", contractName, contractInstance.address, " retrying");
    await timeout(1000);
    code = await provider.getCode(contractInstance.address);
  }
  console.log("Done Deployment " + contractName + " at " + contractInstance.address);
  return contractInstance.address;
}
