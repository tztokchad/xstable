const abi_uniswapv2Router02 = require("../abi/UniswapV2Router02.json");
const abi_erc20 = require("../abi/ERC20.json");

// Arb strategies
const STRAT_UNI_SUSHI = "uni_sushi";
const STRAT_UNI_BAL = "uni_bal";
const STRAT_CRV_LP = "crv_lp";

const STRAT_LIST = [STRAT_UNI_SUSHI, STRAT_UNI_BAL, STRAT_CRV_LP];

// Arb source contract types
const ARB_SRC_TYPE_UNI = "uni";
const ARB_SRC_TYPE_BAL = "bal";
const ARB_SRC_TYPE_CRV = "crv";

const stratAbis = {
  [STRAT_UNI_SUSHI]: {
    from: abi_uniswapv2Router02,
    to: abi_uniswapv2Router02
  }
};

const TOKEN_USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

module.exports = {
  STRAT_UNI_SUSHI,
  STRAT_UNI_BAL,
  STRAT_CRV_LP,
  STRAT_LIST,
  ARB_SRC_TYPE_BAL,
  ARB_SRC_TYPE_CRV,
  ARB_SRC_TYPE_UNI,
  stratAbis,
  abi_erc20,
  TOKEN_USDC
};
