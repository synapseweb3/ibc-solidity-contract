// This is for emitting SendPacket event directly from Axon to initial the IBC communication

async function main() {
  // First provider account.
  const [sender] = await web3.eth.getAccounts();
  // Receiver should be CKB address, which is first 20 bytes of hash of sender's lock_script
  const receiver = process.env.RECEIVER;
  console.log("Sender and receiver:", sender, receiver);

  const ICS20TransferERC20 = await artifacts.require("ICS20TransferERC20Allowlist");

  const transfer = await ICS20TransferERC20.at(
    process.env.TRANSFER_CONTRACT_ADDRESS
  );

  const port = "transfer";
  const channel = process.env.CHANNEL;

  const denom = `${port}/${channel}/${process.env.DENOM}`;

  // Check token associated with the denom that is created before, if not exist, create one
  let tokenAddr = await transfer.denomTokenContract(denom);
  if (tokenAddr == "0x0000000000000000000000000000000000000000") {
    const ERC20PresetMinterPauser = await artifacts.require("ERC20PresetMinterPauser");
    const token_name = process.env.TOKEN_NAME;
    const token_symbol = process.env.TOKEN_SIMBOL;
    const token = await ERC20PresetMinterPauser.new(token_name, token_symbol);
    await token.grantRole(await token.MINTER_ROLE(), transfer.address);
    await token.mint(sender, 999);
    await transfer.setDenomTokenContract(denom, token.address);
    tokenAddr = token.address;
  }

  // Send packet: ERC20 approve and ICS20 sendTransfer.
  await token.approve(transfer.address, 499, {
    from: sender,
  });
  await transfer.sendTransfer(denom, 499, receiver, port, channel, 0, {
    from: sender,
  });
}

module.exports = (callback) => {
  main().then(callback).catch(e => {
    console.log("Error:", e.message, e);
    callback();
  });
};
