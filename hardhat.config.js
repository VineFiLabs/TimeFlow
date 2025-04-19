require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: { 
    Pharos: {
      url: process.env.Pharos_Devnet_Rpc,
      accounts: [process.env.PRIVATE_KEY1]
    },
  },
  solidity: {
    compilers:[
      {version: "0.8.23"},
    ],
    settings: {
      optimizer: {
        enabled: false,
        runs: 200
      }
    }
  },
  gasReporter: {
    enabled: false,  
    currency: 'ETH',  
    // coinmarketcap: 'YOUR_API_KEY',
    outputFile: 'gas-report.txt', 
    noColors: true 
  },
  sourcify: {
    enabled: true
  },
  etherscan: {
    // apiKey: process.env.
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 4000
  }
  };
