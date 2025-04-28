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

//   const testToken = await ethers.getContractFactory("TestToken");
//   const USDT = await testToken.deploy(
//     "TimeFlow Test USDT",
//     "USDT"
//   );
//   const USDTAddress = await USDT.target;
  const USDTAddress = "0xB3aDc46252C2abd33903854A6D5bD37500eAD989";
  console.log("USDT Address:", USDTAddress);

//   const TFPTT = await testToken.deploy(
//     "TimeFlow Test Pharos",
//     "TF-PTT"
//   );
//   const TFPTTAddress = await TFPTT.target;
  const TFPTTAddress = "0xfbF60F3cc210f7931c3c15920CC71A03C0B4dAc3";
  console.log("TFPTT Address:", TFPTTAddress);

  // const dustCore = await ethers.getContractFactory("DustCore");
  // const DustCore = await dustCore.deploy(
  //   owner.address,
  //   owner.address,
  //   {gasLimit: 4500000}
  // );
  // const DustCoreAddress = await DustCore.target;
  const DustCoreAddress = "0xda724A56cfB7945Dbf2AABe16cb276802f91976b";
  const DustCore = new ethers.Contract(DustCoreAddress, DustCoreABI.abi, owner);
  console.log("DustCore Address:", DustCoreAddress);

  // const governance = await ethers.getContractFactory("Governance");
  // const Governance = await governance.deploy(
  //   DustCoreAddress,
  //   owner.address,
  //   owner.address,
  //   owner.address,
  //   {gasLimit: 3500000}
  // );
  // const GovernanceAddress = await Governance.target;
  const GovernanceAddress = "0xbAA41eAe344aff3BADDe497120c71470846B4E06";
  const Governance = new ethers.Contract(
    GovernanceAddress,
    GovernanceABI.abi,
    owner
  );
  console.log("Governance Address:", GovernanceAddress);

  // const setMarketConfig = await Governance.setMarketConfig(
  //   0,
  //   1000000n,
  //   TFPTTAddress,
  //   {gasLimit: 100000}
  // )
  // const setMarketConfigTx = await setMarketConfig.wait();
  // console.log("setMarketConfigTx:", setMarketConfigTx.hash);

  const getMarketConfig = await Governance.getMarketConfig(0);
  console.log("getMarketConfig:", getMarketConfig);

  // const timeFlowFactory = await ethers.getContractFactory("TimeFlowFactory");
  // const TimeFlowFactory = await timeFlowFactory.deploy(GovernanceAddress);
  // const TimeFlowFactoryAddress = await TimeFlowFactory.target;
  const TimeFlowFactoryAddress = "0x83bEde1230B62c1f1bA50c2BC673D94bDE45616F";
  const TimeFlowFactory = new ethers.Contract(TimeFlowFactoryAddress, TimeFlowFactoryABI.abi, owner);
  console.log("TimeFlowFactory Address:", TimeFlowFactoryAddress);

  // const timeFlowHelper = await ethers.getContractFactory("TimeFlowHelper");
  // const TimeFlowHelper = await timeFlowHelper.deploy(
  //   GovernanceAddress,
  //   TimeFlowFactoryAddress,
  //   {gasLimit: 5000000}
  // );
  // const TimeFlowHelperAddress = await TimeFlowHelper.target;
  const TimeFlowHelperAddress = "0x1D84B973697da10E370A4f1e764cD5e0605e6080";
  const TimeFlowHelper = new ethers.Contract(
    TimeFlowHelperAddress,
    TimeFlowHelperABI.abi,
    owner
  );
  console.log("TimeFlowHelper Address:", TimeFlowHelperAddress);

  // const changeTimeFlowFactory = await Governance.changeTimeFlowFactory(
  //   TimeFlowFactoryAddress,
  //   { gasLimit: 300000 }
  // );
  // const changeTimeFlowFactoryTx = await changeTimeFlowFactory.wait();
  // console.log("changeTimeFlowFactory:", changeTimeFlowFactoryTx.hash);

  // const changeConfig = await TimeFlowHelper.changeConfig(
  //   GovernanceAddress,
  //   TimeFlowFactoryAddress,
  //   { gasLimit: 300000 }
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

  const changeCollateral = await Governance.changeCollateral(
    0,
    DustCoreAddress,
    {
      gasLimit: 100000,
    }
  );
  const changeCollateralTx = await changeCollateral.wait();
  console.log("changeCollateral:", changeCollateralTx.hash);

  const changeCollateral2 = await Governance.changeCollateral(
    1,
    DustCoreAddress,
    {
      gasLimit: 100000,
    }
  );
  const changeCollateral2Tx = await changeCollateral2.wait();
  console.log("changeCollateral2:", changeCollateral2Tx.hash);

  const initialize = await DustCore.initialize([95], [10], [USDTAddress], {
    gasLimit: 100000,
  });
  const initializeTx = await initialize.wait();
  console.log("initialize:", initializeTx.hash);

  // const createMarket1 = await TimeFlowFactory.createMarket({ gasLimit: 5200000n });
  // const createMarket1Tx = await createMarket1.wait();
  // console.log("createMarket1 tx:", createMarket1Tx.hash);

  // const createMarket2 = await TimeFlowFactory.createMarket({ gasLimit: 5200000n });
  // const createMarket2Tx = await createMarket2.wait();
  // console.log("createMarket2 tx:", createMarket2Tx.hash);

  const marketId = await TimeFlowFactory.marketId();
  console.log("marketId:", marketId);

  const getMarketInfo1 = await TimeFlowFactory.getMarketInfo(0n);
  console.log("getMarketInfo1:", getMarketInfo1);

  const getMarketInfo2 = await TimeFlowFactory.getMarketInfo(1n);
  console.log("getMarketInfo2:", getMarketInfo2);

  // const getMarketInfo3 = await TimeFlowFactory.getMarketInfo(2n);
  // console.log("getMarketInfo3:", getMarketInfo3);

  const Market = new ethers.Contract(
    getMarketInfo1[0],
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
    getMarketInfo1[0],
    ethers.parseEther("1000000000")
  );

  await Approve(
    USDTAddress,
    DustCoreAddress,
    ethers.parseEther("1000000000")
  );

  // const initMarketConfig2 = await Governance.initMarketConfig(
  //     1,
  //     DustCoreAddress,
  //     ZERO_ADDRESS,
  //     ZERO_ADDRESS,
  //     {gasLimit: 250000}
  //   );
  //   const initMarketConfig2Tx = await initMarketConfig2.wait();
  //   console.log("initMarketConfig2Tx:", initMarketConfig2Tx.hash);

  //   const setMarketConfig2 = await Governance.setMarketConfig(
  //     1,
  //     100000n,
  //     TFPTTAddress,
  //     {gasLimit: 500000}
  //   )
  //   const setMarketConfig2Tx = await setMarketConfig2.wait();
  //   console.log("setMarketConfig2Tx:", setMarketConfig2Tx.hash);

  // const mintDust = await DustCore.mintDust(
  //   USDTAddress, 
  //   10000n * 10n ** 18n,
  //   1000000n,
  //   {gasLimit: 1200000}
  // );
  // const mintDustTx = await mintDust.wait();
  // console.log("mintDust tx:", mintDustTx.hash);

  const OrderType = {
    buy: 0,
    sell: 1,
  };

  // const putTrade = await Market.putTrade(
  //   OrderType.sell,
  //   50n * 10n ** 18n,
  //   1n * 10n ** 6n,
  //   { gasLimit: 500000 }
  // );
  // const putTradeTx = await putTrade.wait();
  // console.log("putTradeTx:", putTradeTx.hash);

  // const matchTrade = await Market.matchTrade(
  //   OrderType.buy,
  //   50n * 10n ** 18n,
  //   1n * 10n ** 6n,
  //   [0],
  //   {gasLimit: 500000}
  // );
  // const matchTradeTx = await matchTrade.wait();
  // console.log("matchTradeTx:", matchTradeTx.hash);

  //

  config.USDT = USDTAddress;
  config.PTT = TFPTTAddress;
  config.DustCore = DustCoreAddress;
  (config.Governance = GovernanceAddress),
    (config.TimeFlowFactory = TimeFlowFactoryAddress),
    (config.TimeFlowHelper = TimeFlowHelperAddress);
  (config.market0 = getMarketInfo1[0]),
  (config.market1 = getMarketInfo2[0]),
  // (config.market2 = getMarketInfo3[0]),
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
