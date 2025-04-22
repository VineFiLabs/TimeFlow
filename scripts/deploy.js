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

  // const testToken = await ethers.getContractFactory("TestToken");
  // const USDT = await testToken.deploy(
  //   "TimeFlow Test USDT",
  //   "USDT"
  // );
  // const USDTAddress = await USDT.target;
  const USDTAddress = "0xFA8B026CaA2d1d73CE8A9f19613364FCa9440411";
  console.log("USDT Address:", USDTAddress);

  // const TFPTT = await testToken.deploy(
  //   "TimeFlow Test Pharos",
  //   "TF-PTT"
  // );
  // const TFPTTAddress = await TFPTT.target;
  const TFPTTAddress = "0xa5281122370d997c005B2313373Fa3CAf6A48Ae0";
  console.log("TFPTT Address:", TFPTTAddress);

  // const dustCore = await ethers.getContractFactory("DustCore");
  // const DustCore = await dustCore.deploy(
  //   owner.address,
  //   owner.address,
  //   {gasLimit: 4500000}
  // );
  // const DustCoreAddress = await DustCore.target;
  const DustCoreAddress = "0xbeE864df76A3418CF81A2D46768Dc17CB61fc68B";
  const DustCore = new ethers.Contract(DustCoreAddress, DustCoreABI.abi, owner);
  console.log("DustCore Address:", DustCoreAddress);

  // const governance = await ethers.getContractFactory("Governance");
  // const Governance = await governance.deploy(
  //   DustCoreAddress,
  //   owner.address,
  //   owner.address,
  //   owner.address,
  //   {gasLimit: 3000000}
  // );
  // const GovernanceAddress = await Governance.target;
  const GovernanceAddress = "0x6d7d5012bae4D59D5D6A88e2751921e6f8A7Fe95";
  const Governance = new ethers.Contract(
    GovernanceAddress,
    GovernanceABI.abi,
    owner
  );
  console.log("Governance Address:", GovernanceAddress);

  // const setMarketConfig = await Governance.setMarketConfig(
  //   0,
  //   200000n,
  //   TFPTTAddress,
  //   {gasLimit: 100000}
  // )
  // const setMarketConfigTx = await setMarketConfig.wait();
  // console.log("setMarketConfigTx:", setMarketConfigTx.hash);

  const getMarketConfig = await Governance.getMarketConfig(0);
  console.log("getMarketConfig:", getMarketConfig);

  // const timeFlowFactory = await ethers.getContractFactory("TimeFlowFactory");
  // const TimeFlowFactory = await timeFlowFactory.deploy(GovernanceAddress, {
  //   gasLimit: 6000000,
  // });
  // const TimeFlowFactoryAddress = await TimeFlowFactory.target;
  const TimeFlowFactoryAddress = "0x9fF1d2bb090915C22f0e660F096958146BE335e3";
  const TimeFlowFactory = new ethers.Contract(TimeFlowFactoryAddress, TimeFlowFactoryABI.abi, owner);
  console.log("TimeFlowFactory Address:", TimeFlowFactoryAddress);

  // const timeFlowHelper = await ethers.getContractFactory("TimeFlowHelper");
  // const TimeFlowHelper = await timeFlowHelper.deploy(
  //   GovernanceAddress,
  //   TimeFlowFactoryAddress,
  //   {gasLimit: 3000000}
  // );
  // const TimeFlowHelperAddress = await TimeFlowHelper.target;
  const TimeFlowHelperAddress = "0x53729c83EAB6AD7C9d2c66f18CCB73F6D3d90460";
  const TimeFlowHelper = new ethers.Contract(
    TimeFlowHelperAddress,
    TimeFlowHelperABI.abi,
    owner
  );
  console.log("TimeFlowHelper Address:", TimeFlowHelperAddress);

  // const changeConfig = await TimeFlowHelper.changeConfig(
  //   GovernanceAddress,
  //   TimeFlowFactoryAddress,
  //   { gasLimit: 100000 }
  // );
  // const changeConfigTx = await changeConfig.wait();
  // console.log("changeConfig:", changeConfigTx.hash);

  // const initMarketConfig = await Governance.initMarketConfig(
  //   0,
  //   DustCoreAddress,
  //   ZERO_ADDRESS,
  //   ZERO_ADDRESS,
  //   {gasLimit: 100000}
  // );
  // const initMarketConfigTx = await initMarketConfig.wait();
  // console.log("initMarketConfigTx:", initMarketConfigTx.hash);

  // const changeCollateral = await Governance.changeCollateral(
  //   0,
  //   DustCoreAddress,
  //   {
  //     gasLimit: 100000,
  //   }
  // );
  // const changeCollateralTx = await changeCollateral.wait();
  // console.log("changeCollateral:", changeCollateralTx.hash);

  // const initialize = await DustCore.initialize([95], [10], [USDTAddress], {
  //   gasLimit: 100000,
  // });
  // const initializeTx = await initialize.wait();
  // console.log("initialize:", initializeTx.hash);

  // const createMarket = await TimeFlowFactory.createMarket({ gasLimit: 5000000n });
  // const createMarketTx = await createMarket.wait();
  // console.log("createMarket tx:", createMarketTx.hash);

  const marketId = await TimeFlowFactory.marketId();
  console.log("marketId:", marketId);

  const getMarketInfo = await TimeFlowFactory.getMarketInfo(0n);
  console.log("getMarketInfo:", getMarketInfo);

  const Market = new ethers.Contract(
    getMarketInfo[0],
    TimeFlowCoreABI.abi,
    owner
  );

  const getExpectedAmount = await DustCore.getExpectedAmount(
    USDTAddress,
    100n * 10n ** 18n,
    1000000n
  );
  console.log("getExpectedAmount:", getExpectedAmount);

  const getDustCollateralInfo = await DustCore.getDustCollateralInfo(USDTAddress);
  console.log("getDustCollateralInfo:", getDustCollateralInfo);

  async function Approve(token, spender, amount) {
    try {
      const tokenContract = new ethers.Contract(token, ERC20ABI.abi, owner);
      const allowance = await tokenContract.allowance(owner.address, spender);
      if (allowance < ethers.parseEther("10000")) {
        const approve = await tokenContract.approve(spender, amount);
        const approveTx = await approve.wait();
        console.log("approveTx:", approveTx.hash);
      } else {
        console.log("Not approve");
      }
    } catch (e) {
      console.log("e:", e);
    }
  }
  await Approve(
    DustCoreAddress,
    getMarketInfo[0],
    ethers.parseEther("1000000000")
  );

  await Approve(
    USDTAddress,
    DustCoreAddress,
    ethers.parseEther("1000000000")
  );

  const mintDust = await DustCore.mintDust(
    USDTAddress, 
    10000n * 10n ** 18n,
    1000000n,
    {gasLimit: 1200000}
  );
  const mintDustTx = await mintDust.wait();
  console.log("mintDust tx:", mintDustTx.hash);

  const OrderType = {
    buy: 0,
    sell: 1,
  };

  const putTrade = await Market.putTrade(
    OrderType.buy,
    20,
    ethers.parseEther("1"),
    { gasLimit: 500000 }
  );
  const putTradeTx = await putTrade.wait();
  console.log("putTradeTx:", putTradeTx.hash);

  //

  config.USDT = USDTAddress;
  config.PTT = TFPTTAddress;
  config.DustCore = DustCoreAddress;
  (config.Governance = GovernanceAddress),
    (config.TimeFlowFactory = TimeFlowFactoryAddress),
    (config.TimeFlowHelper = TimeFlowHelperAddress);
  (config.market = getMarketInfo[0]),
    (config.updateTime = new Date().toISOString());

  const filePath = "./deployedAddress.json";
  if (fs.existsSync(filePath)) {
    allAddresses = JSON.parse(fs.readFileSync(filePath, "utf8"));
  }
  allAddresses[chainId] = config;

  fs.writeFileSync(filePath, JSON.stringify(allAddresses, null, 2), "utf8");
  console.log("deployedAddress.json update：", allAddresses);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
