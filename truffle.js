require("babel-register");
require("babel-polyfill");
const TestRPC = require("ethereumjs-testrpc");
const nanoWeb3Provider = require("./nanoWeb3Provider");

const providerUrl = "http://localhost:8545";
const nanoPath = "44'/60'/0'/0`";

module.exports = {
  networks: {
    localhost: {
      network_id: "*",
      host: "localhost",
      port: 8545
    },
    inprocess: {
      network_id: "*",
      provider: TestRPC.provider({
        accounts: Array(10).fill({ balance: "12300000000000000000000000" })
      })
    },
    inprocess_test: {
      network_id: "*",
      provider: TestRPC.provider({
        accounts: Array(10).fill({ balance: "12300000000000000000000000" })
      })
    },
    coverage: {
      network_id: "*",
      gas: 0xfffffffffff,
      gasPrice: 1,
      host: "localhost",
      port: 8555
    },
    ropsten: {
      host: "localhost", // local parity kovan node
      port: 8545,
      network_id: "3"
    },
    kovan: {
      host: "localhost", // local parity kovan node
      port: 8545,
      network_id: "42"
    },
    ropsten_live: {
      host: "localhost", // local parity kovan node
      port: 8545,
      network_id: "3"
    },
    nano: {
      network_id: "*",
      host: "localhost",
      port: 8545,
      gas: 4600000,
      provider: nanoWeb3Provider.nanoWeb3Provider(providerUrl, nanoPath) // Our costume instance
    },
    simulated_live: {
      network_id: "*",
      host: "localhost",
      port: 8545,
      gas: 4600000
    },
    nf_private: {
      host: "localhost",
      port: 8545,
      network_id: "16",
      gas: 4600000,
      // gasPrice: 11904761856
      gasPrice: 21000000000
    },
    nf_private_test: {
      host: "localhost",
      port: 8545,
      network_id: "16",
      gas: 4600000,
      // gasPrice: 11904761856
      gasPrice: 21000000000
    },
    nf_dev_test: {
      host: "localhost",
      port: 8545,
      network_id: "17",
      gas: 4600000,
      // gasPrice: 11904761856
      gasPrice: 21000000000
    },
    live: {
      network_id: 1, // Ethereum public network
      host: "192.168.100.30",
      port: 8545,
      gas: 4300000, // close to current mainnet limit
      gasPrice: 21000000000 // 21 gwei /shannon
      // optional config values
      // host - defaults to "localhost"
      // port - defaults to 8545
      // gas
      // gasPrice
      // from - default address to use for any transaction Truffle makes during migrations
    }
  }
};
