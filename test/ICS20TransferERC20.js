const IBCHandler = artifacts.require("IBCMockHandler");
const ICS20TransferERC20 = artifacts.require("ICS20TransferERC20Test");
const ERC20PresetMinterPauser = artifacts.require("ERC20PresetMinterPauser");

contract("ICS20TransferERC20", ([account]) => {
  it("should be able to mint/burn ERC20", async () => {
    const ibcHandler = await IBCHandler.deployed();
    const ics20TransferErc20 = await ICS20TransferERC20.new(ibcHandler.address);
    const myToken = await ERC20PresetMinterPauser.new("MyToken", "MT");

    const denom = "/port-2/transfer-8/MY-TOKEN-TYPE-SCRIPT-HASH";

    await myToken.grantRole(
      await myToken.MINTER_ROLE(),
      ics20TransferErc20.address
    );
    await ics20TransferErc20.setDenomTokenContract(denom, myToken.address);

    await ics20TransferErc20.mint(account, denom, 100);

    assert.equal(await myToken.balanceOf(account), 100);

    await myToken.approve(ics20TransferErc20.address, 50);
    await ics20TransferErc20.burn(account, denom, 50);

    assert.equal(await myToken.balanceOf(account), 50);
  });
});
