const IBCHandler = artifacts.require("IBCMockHandler");
const ICS20TransferERC20Allowlist = artifacts.require(
  "ICS20TransferERC20AllowlistTest"
);
const ERC20PresetMinterPauser = artifacts.require("ERC20PresetMinterPauser");

contract("ICS20TransferERC20Allowlist", ([account]) => {
  it("should be able to mint/burn ERC20", async () => {
    const ibcHandler = await IBCHandler.deployed();
    const transfer = await ICS20TransferERC20Allowlist.new(ibcHandler.address);
    const myToken = await ERC20PresetMinterPauser.new("MyToken", "MT");

    const denom = "/port-2/transfer-8/MY-TOKEN-TYPE-SCRIPT-HASH";

    await myToken.grantRole(await myToken.MINTER_ROLE(), transfer.address);
    await transfer.setDenomTokenContract(denom, myToken.address);

    await transfer.mintShouldFail(account, "/port/channel/unknown-denom", 100);
    await transfer.mint(account, denom, 100);

    assert.equal(await myToken.balanceOf(account), 100);
    assert.equal(await myToken.totalSupply(), 100);

    await transfer.burnShouldFail(account, "/port/channel/unknown-denom", 49);
    // Burn without allowance should fail.
    await transfer.burnShouldFail(account, denom, 49);

    await myToken.approve(transfer.address, 49, { from: account });
    await transfer.burn(account, denom, 49);

    assert.equal(await myToken.balanceOf(account), 51);
    assert.equal(await myToken.totalSupply(), 51);
  });

  it("should be able to transfer ERC20", async () => {
    const ibcHandler = await IBCHandler.deployed();
    const transfer = await ICS20TransferERC20Allowlist.new(ibcHandler.address);
    const myToken = await ERC20PresetMinterPauser.new("MyToken", "MT");

    await myToken.mint(account, 100);
    // Transfer without allowance should fail.
    await transfer.transferFromShouldFail(
      account,
      transfer.address,
      myToken.address,
      51
    );
    await myToken.approve(transfer.address, 51, { from: account });
    await transfer.transferFrom(account, transfer.address, myToken.address, 51);
    assert.equal(await myToken.balanceOf(account), 49);
  });
});
