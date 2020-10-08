require("dotenv").config();

const Web3 = require("web3");
const HDWalletProvider = require("truffle-hdwallet-provider");

const Arb = require("./src/arb");
const Events = require("./src/events");

const {
  MNEMONIC,
  PRIVATE_KEY,
  WEB3_URL,
  STRAT_LIST,
  PROFIT_THRESHOLD,
  GAS_PRICE,
  ROUTER_1_FACTORY_ADDRESS,
  ROUTER_1_INIT_CODE_HASH,
  ROUTER_2_FACTORY_ADDRESS,
  ROUTER_2_INIT_CODE_HASH,
  UNI_ARB_PAIRS,
  UNI_BAL_PAIRS
} = process.env;

(async () => {
  let web3;
  if (MNEMONIC) web3 = new Web3(new HDWalletProvider(MNEMONIC, WEB3_URL));
  else if (PRIVATE_KEY) web3 = new Web3(WEB3_URL);
  else
    throw new Error(
      "no auth set. Please set a mnemonic or private key in .env"
    );
  const config = {
    tokens: TOKEN_LIST,
    strats: STRAT_LIST,
    profitThreshold: PROFIT_THRESHOLD,
    gasPrice: GAS_PRICE,
    chainId: await web3.eth.getChainId(),
    router1FactoryAddress: ROUTER_1_FACTORY_ADDRESS,
    router1InitCodeHash: ROUTER_1_INIT_CODE_HASH,
    router2FactoryAddress: ROUTER_2_FACTORY_ADDRESS,
    router2InitCodeHash: ROUTER_2_INIT_CODE_HASH,
    uniArbPairs: UNI_ARB_PAIRS,
    uniBalPairs: UNI_BAL_PAIRS
  };
  const events = new Events(web3);
  const arb = new Arb(web3, events, config);
})();
