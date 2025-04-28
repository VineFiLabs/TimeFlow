const hre = require("hardhat");
const fs = require("fs");

const GovernanceABI = require("../artifacts/contracts/core/Governance.sol/Governance.json");
const TimeFlowFactoryABI = require("../artifacts/contracts/core/TimeFlowFactory.sol/TimeFlowFactory.json");
const TimeFlowCoreABI = require("../artifacts/contracts/core/TimeFlowCore.sol/TimeFlowCore.json");
const DustCoreABI = require("../artifacts/contracts/core/DustCore.sol/DustCore.json");
const ERC20ABI = require("../artifacts/contracts/TestToken.sol/TestToken.json");
const TimeFlowHelperABI = require("../artifacts/contracts/helper/TimeFlowHelper.sol/TimeFlowHelper.json");

async function main() {
  const [owner] = await hre.ethers.getSigners();
  console.log("owner:", owner.address);

  const provider = ethers.provider;
  const network = await provider.getNetwork();
  const chainId = network.chainId;
  console.log("Chain ID:", chainId);

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  let config = {};

  async function sendETH(toAddress, amountInEther) {
    const amountInWei = ethers.parseEther(amountInEther);
    const tx = {
      to: toAddress,
      value: amountInWei,
    };
    const transactionResponse = await owner.sendTransaction(tx);
    await transactionResponse.wait();
    console.log("Transfer eth success");
  }

  let allAddresses = {};

  const USDTAddress = "0xB3aDc46252C2abd33903854A6D5bD37500eAD989";
  console.log("USDT Address:", USDTAddress);

  const TFPTTAddress = "0xfbF60F3cc210f7931c3c15920CC71A03C0B4dAc3";
  console.log("TFPTT Address:", TFPTTAddress);

  const DustCoreAddress = "0xe082b5a1F1aEf5fA15e4B9ACB2bDa74A2a0BDE3e";
  const DustCore = new ethers.Contract(DustCoreAddress, DustCoreABI.abi, owner);
  console.log("DustCore Address:", DustCoreAddress);

  const GovernanceAddress = "0x22cC3C7BA8e51DB094Ca0534Eaf1D0Bdcb9d2965";
  const Governance = new ethers.Contract(
    GovernanceAddress,
    GovernanceABI.abi,
    owner
  );
  console.log("Governance Address:", GovernanceAddress);

  const getMarketConfig = await Governance.getMarketConfig(0);
  console.log("getMarketConfig:", getMarketConfig);

  const TimeFlowFactoryAddress = "0x02aFc4C0614ee437affa795BebBbd9EdAfc0AbF7";
  const TimeFlowFactory = new ethers.Contract(TimeFlowFactoryAddress, TimeFlowFactoryABI.abi, owner);
  console.log("TimeFlowFactory Address:", TimeFlowFactoryAddress);

  const TimeFlowHelperAddress = "0xf1BE4eE55Bf69A7f8e1fbD2EF73cE9E7fdE8cb61";
  const TimeFlowHelper = new ethers.Contract(
    TimeFlowHelperAddress,
    TimeFlowHelperABI.abi,
    owner
  );
  console.log("TimeFlowHelper Address:", TimeFlowHelperAddress);

  const getOrderInfo = await TimeFlowHelper.getOrderInfo(
    1,
    1
  );
  console.log("getOrderInfo:", getOrderInfo);

  const getOrderState = await TimeFlowHelper.getOrderState(
    1,
    1
  );
  console.log("getOrderState:", getOrderState);



}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
