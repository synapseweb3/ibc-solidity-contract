// This is part of ckb <-> axon SUDT <-> ERC20 transfer test.

async function main() {
  // First provider account.
  const [receiver] = await web3.eth.getAccounts();
  console.log("Receiver should be:", receiver);
  const sender = process.env.SENDER;

  const ICS20TransferERC20 = await artifacts.require("ICS20TransferERC20Allowlist");
  const IERC20 = await artifacts.require("IERC20");

  const transfer = await ICS20TransferERC20.at(
    process.env.TRANSFER_CONTRACT_ADDRESS
  );

  const port = "transfer";
  const channel = process.env.CHANNEL;

  const denom = `${port}/${channel}/${process.env.DENOM}`;

  // Wait till the token is deployed.
  let tokenAddr;
  while (true) {
    tokenAddr = await transfer.denomTokenContract(denom);
    if (tokenAddr == "0x0000000000000000000000000000000000000000") {
      console.log("token not deployed yet");
      await sleep(1000);
      continue;
    } else {
      break;
    }
  }

  // Check balance.
  const token = await IERC20.at(tokenAddr);
  if ((await token.balanceOf(receiver)) != 999) {
    throw "balance should be 999";
  }

  // Send back: ERC20 approve and ICS20 sendTransfer.
  await token.approve(transfer.address, 499, {
    from: receiver,
  });
  await transfer.sendTransfer(denom, 499, sender, port, channel, 0, {
    from: receiver,
  });
}

module.exports = (callback) => {
  main().then(callback).catch(e => {
    console.log("Error:", e.message, e);
    callback();
  });
};

function sleep(millis) {
  return new Promise((resolve) => {
    setTimeout(resolve, millis);
  });
}
