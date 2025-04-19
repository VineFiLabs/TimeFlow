const hre = require("hardhat");
const fs = require("fs");

const GovernanceABI = require("../artifacts/contracts/core/Governance.sol/Governance.json");
const TimeFlowFactoryABI = require("../artifacts/contracts/core/TimeFlowFactory.sol/TimeFlowFactory.json");
const TimeFlowCoreABI = require("../artifacts/contracts/core/TimeFlowCore.sol/TimeFlowCore.json");
const DustCoreABI = require("../artifacts/contracts/core/DustCore.sol/DustCore.json");
const DustABI = require("../artifacts/contracts/core/Dust.sol/Dust.json");
const ERC20ABI = require("../artifacts/contracts/TestToken.sol/TestToken.json");

async function main() {
  const [owner] = await hre.ethers.getSigners();
  console.log("owner:", owner.address);

  const provider = ethers.provider;
  const network = await provider.getNetwork();
  const chainId = network.chainId;
  console.log("Chain ID:", chainId);

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  let config={};

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

  // const governance = await ethers.getContractFactory("Governance");
  // const Governance = await governance.deploy(
  //   owner.address,
  //   owner.address,
  //   owner.address,
  //   owner.address
  // );
  // const GovernanceAddress = await Governance.target;
  const GovernanceAddress = "0xB3aDc46252C2abd33903854A6D5bD37500eAD989";
  const Governance = new ethers.Contract(GovernanceAddress, GovernanceABI.abi, owner);
  console.log("Governance Address:", GovernanceAddress);

  // const initMarketConfig = await Governance.initMarketConfig(
  //   0,
  //   USDTAddress,
  //   ZERO_ADDRESS,
  //   ZERO_ADDRESS
  // );
  // const initMarketConfigTx = await initMarketConfig.wait(); 
  // console.log("initMarketConfigTx:", initMarketConfigTx.hash);

  // const setMarketConfig = await Governance.setMarketConfig(
  //   0,
  //   864000n,
  //   TFPTTAddress
  // )
  // const setMarketConfigTx = await setMarketConfig.wait(); 
  // console.log("setMarketConfigTx:", setMarketConfigTx.hash);

  const getMarketConfig = await Governance.getMarketConfig(0);
  console.log("getMarketConfig:", getMarketConfig);

  const timeFlowFactory = await ethers.getContractFactory("TimeFlowFactory");
  const TimeFlowFactory = await timeFlowFactory.deploy(
    GovernanceAddress
  );
  const TimeFlowFactoryAddress = await TimeFlowFactory.target;
  // const TimeFlowFactoryAddress = "0xBD4160794972C1e9b09a081bc8AFB2A51965F735";
  // const TimeFlowFactory = new ethers.Contract(TimeFlowFactoryAddress, TimeFlowFactoryABI.abi, owner);
  console.log("TimeFlowFactory Address:", TimeFlowFactoryAddress);

  const timeFlowHelper = await ethers.getContractFactory("TimeFlowHelper");
  const TimeFlowHelper = await timeFlowHelper.deploy(
    GovernanceAddress,
    TimeFlowFactoryAddress
  );
  const TimeFlowHelperAddress = await TimeFlowHelper.target;
  // const TimeFlowHelperAddress = "0x2d0DEEba4d7C14a88D48630c20E5fE9afe3B5BC3";
  // console.log("TimeFlowHelper Address:", TimeFlowHelperAddress);

  const dustCore = await ethers.getContractFactory("DustCore");
  const DustCore = await dustCore.deploy(
    owner.address,
    owner.address
  );
  const DustCoreAddress = await DustCore.target;
  // const DustCoreAddress = "0x6Bb65a41103DD7df9D3585Aee692756A0D3B4908";
  // const DustCore = new ethers.Contract(DustCoreAddress, DustCoreABI.abi, owner);
  console.log("DustCore Address:", DustCoreAddress);

  const dust = await ethers.getContractFactory("Dust");
  const Dust = await dust.deploy(
    DustCoreAddress
  );
  const DustAddress = await Dust.target;
  // const DustAddress = "0x672Dc6b47553D576bc955589Cd87CC0f9886AeA9";
  // const Dust = new ethers.Contract(DustAddress, DustABI.abi, owner);
  console.log("Dust Address:", DustAddress);

  
  const initialize =await DustCore.initialize(
    DustAddress,
    [95],
    [10],
    [USDTAddress]
  );
  const initializeTx = await initialize.wait();
  console.log("initialize:", initializeTx.hash);

  const createMarket = await TimeFlowFactory.createMarket({ gasLimit: 5000000n });
  const createMarketTx = await createMarket.wait();
  console.log("createMarket tx:", createMarketTx.hash);

  const marketId = await TimeFlowFactory.marketId();
  console.log("marketId:", marketId);

  const getMarketInfo = await TimeFlowFactory.getMarketInfo(marketId - 1n);
  console.log("getMarketInfo:", getMarketInfo);

  const Market = new ethers.Contract(getMarketInfo[0], TimeFlowCoreABI.abi, owner);

  async function Approve(token, spender, amount){
    try{
      const tokenContract = new ethers.Contract(token, ERC20ABI.abi, owner);
      const allowance = await tokenContract.allowance(owner.address, spender);
      if(allowance < ethers.parseEther("10000")){
        const approve = await tokenContract.approve(spender, amount);
        const approveTx = await approve.wait();
        console.log("approveTx:", approveTx.hash);
      }else{
        console.log("Not approve");
      }
    }catch(e){
      console.log("e:", e);
    }
  }
  await Approve(USDTAddress, getMarketInfo[0], ethers.parseEther("1000000000"));

  const OrderType = {
    buy: 0,
    sell: 1
  }

  const putTrade = await Market.putTrade(
    OrderType.buy,
    1000,
    ethers.parseEther("0.1"),
    { gasLimit: 3000000n }
  );
  const putTradeTx = await putTrade.wait();
  console.log("putTradeTx:", putTradeTx.hash);

  //

  config.USDT = USDTAddress;
  config.PTT = TFPTTAddress;
  config.DustCore = DustCoreAddress;
  config.Dust = DustAddress;
  config.Governance = GovernanceAddress,
  config.TimeFlowFactory = TimeFlowFactoryAddress,
  config.TimeFlowHelper = TimeFlowHelperAddress;
  config.market = getMarketInfo[0],
  config.updateTime = new Date().toISOString()


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
