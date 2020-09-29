const HDWalletProvider = require('truffle-hdwallet-provider')
require('dotenv').config()

module.exports = {
  networks: {
    ropsten: {
      provider: () =>
        new HDWalletProvider(process.env.MNEMONIC, process.env.URL),
      network_id: 3,
      gas: 4000000,
      timeoutBlocks: 3,
      gasPrice: 7000000000,
    },
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gas: 20000000, // Rinkeby has a lower block limit than mainnet
      confirmations: 0, // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 2000, // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true, // Skip dry run before migrations? (default: false for public nets )
      gasPrice: 7000000000, // 7 gwei (in wei) (default: 100 gwei)
    },
  },
  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
    recursive: true,
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: '0.6.10',
    },
  },
}
