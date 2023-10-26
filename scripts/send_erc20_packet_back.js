// This is for emitting SendPacket event directly from Axon to initial the IBC communication

async function main() {
  // First provider account.
  const [sender] = await web3.eth.getAccounts();
  // Receiver should be CKB address, which is first 20 bytes of hash of sender's lock_script
  const receiver = process.env.RECEIVER;
  console.log("Sender and receiver:", sender, receiver);

  const ICS20TransferERC20 = await artifacts.require("ICS20TransferERC20");
  const IERC20 = await artifacts.require("IERC20");

  const transfer = await ICS20TransferERC20.at(
    process.env.TRANSFER_CONTRACT_ADDRESS
  );

  const port = "transfer";
  const channel = process.env.CHANNEL;

  const denom = `${port}/${channel}/${process.env.DENOM}`;

  // Check token associated with the denom that is created before
  let tokenAddr = await transfer.denomTokenContract(denom);
  if (tokenAddr == "0x0000000000000000000000000000000000000000") {
    // const ERC20PresetMinterPauser = await artifacts.require("ERC20PresetMinterPauser");
    // const token_name = process.env.TOKEN_NAME;
    // const token_symbol = process.env.TOKEN_SIMBOL;
    // const token = await ERC20PresetMinterPauser.new(token_name, token_symbol);
    // await token.grantRole(await token.MINTER_ROLE(), transfer.address);
    // await token.mint(sender, 999);
    // await transfer.setDenomTokenContract(denom, token.address);
    // tokenAddr = token.address;
    console.error("Axon cannot be source zone now, so the transferred token should already exist on CKB");
    return;
  }

  // Check balance.
  const amount = process.env.AMOUNT;
  const token = await IERC20.at(tokenAddr);
  if ((await token.balanceOf(receiver)) >= amount) {
    throw "balance should at least be " + amount;
  }

  // Send packet: ERC20 approve and ICS20 sendTransfer.
  await token.approve(transfer.address, amount, {
    from: sender,
  });
  let result = await transfer.sendTransfer(denom, amount, receiver, port, channel, 0, {
    from: sender,
  });
  console.log(`Successfully send ${amount} token to ${receiver} with denom ${denom}: ${result}`);
}

module.exports = (callback) => {
  main().then(callback).catch(e => {
    console.log("Error:", e.message, e);
    callback();
  });
};
