const IBCHandler = artifacts.require("IBCMockHandler");
const ICS20TransferERC20 = artifacts.require("ICS20TransferERC20Test");
const ERC20PresetMinterPauser = artifacts.require("ERC20PresetMinterPauser");

contract("ICS20TransferERC20", ([account]) => {
  it("should be able to mint ERC20", async () => {
    const ibcHandler = await IBCHandler.deployed();
    const transfer = await ICS20TransferERC20.new(ibcHandler.address);

    const denom = "/port-2/transfer-8/MY-TOKEN-TYPE-SCRIPT-HASH";

    await transfer.mint(account, denom, 100);
    await transfer.mint(account, denom, 51);
    const myToken = await ERC20PresetMinterPauser.at(
      await transfer.denomTokenContract(denom)
    );

    assert.equal(
      await myToken.name(),
      "IBC/A74473C8545D36443C16874E2A336A00016EF1C0EA489CE552A76EE1709CE50D"
    );
    assert.equal(await myToken.balanceOf(account), 151);
    assert.equal(await myToken.totalSupply(), 151);
  });
  // Other functions are tested in ICS20TransferERC20Allowlist
});
