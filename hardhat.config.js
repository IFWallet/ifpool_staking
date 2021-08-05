const fs = require('fs')
const path = require('path')

require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config();

const mnemonic = process.env.MNEMONIC;
const infuraKey = process.env.INFURA_KEY;
const etherscanKey = process.env.ETHERSCAN_KEY;
const MNEMONIC_PATH = "m/44'/60'/0'/0";

const SKIP_LOAD = process.env.SKIP_LOAD === 'true';

// Prevent to load scripts before compilation and typechain
if (!SKIP_LOAD) {
  ['init', 'helpers'].forEach(
    (folder) => {
      const tasksPath = path.join(__dirname, 'tasks', folder);
      fs.readdirSync(tasksPath)
        .filter((pth) => pth.includes('.js'))
        .forEach((task) => {
          require(`${tasksPath}/${task}`);
        });
    }
  );
}


// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000
      }
    }
  },
  networks: {
    coinex: {
      url: 'https://rpc.coinex.net/',
      chainId: 52,
      hardfork: 'berlin',
      blockGasLimit: 6721975,
      gas: 6721975,
      accounts: {
        mnemonic: mnemonic,
        path: MNEMONIC_PATH,
        initialIndex: 0,
        count: 20,
      },
    },
    coinexTest: {
      url: 'http://127.0.0.1:8545/',
      chainId: 53,
      hardfork: 'berlin',
      blockGasLimit: 9500000,
      gas: 9500000,
      accounts: {
        mnemonic: mnemonic,
        path: MNEMONIC_PATH,
        initialIndex: 0,
        count: 20,
      },
    },
    localTest: {
      url: 'http://127.0.0.1:9545/',
      chainId: 1337,
      hardfork: 'berlin',
      blockGasLimit: 6721975,
      gas: 6721975,
      accounts: {
        mnemonic: mnemonic,
        path: MNEMONIC_PATH,
        initialIndex: 0,
        count: 20,
      },
    },
  }
};
