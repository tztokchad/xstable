const { ChainId, Token, TokenAmount, WETH, Fetcher, Router, Trade, TradeType } = require("@uniswap/sdk");

const {
  STRAT_CRV_LP,
  STRAT_UNI_BAL,
  STRAT_UNI_SUSHI,
  ARB_SRC_TYPE_BAL,
  ARB_SRC_TYPE_CRV,
  ARB_SRC_TYPE_UNI
} = require("../util/constants");

function Arb(web3, events, config) {
  const { tokens, strats, profitThreshold, gasPrice, chainId } = config;

  this.arb = () => {};

  /**
   * Returns the last price for a given token 1 -> token 2 given the source contract and it's type
   * @param _src Source contract
   * @param _type Type of contract
   * @param _token1 Address of token 1
   * @param _token2 Address of token 2
   * @param _inputAmount Input token amount
   * @return Last price of token
   */
  const _getLastPrice = (_src, _type, _token1, _token2, _inputAmount) => {
    if (type === ARB_SRC_TYPE_BAL) {
      return src.methods.getSpotPrice(token1, token2);
    } else if (type === ARB_SRC_TYPE_UNI) {
      // TODO: Get decimals from token contract
      const token1 = new Token(chainId, _token1, 18);
      const token2 = new Token(chainId, _token2, 18);
      
      const pair = await Fetcher.fetchPairData(token1, token2);
      const route = new Route([pair], token2);
      const trade = new Trade(route, new TokenAmount(token2, _inputAmount), TradeType.EXACT_INPUT);
      return trade.executionPrice.toSignificant(6);
    } else if (type === ARB_SRC_TYPE_CRV) {

    }
  };

  const _getStratEvents = strat => {};
}

module.exports = Arb;
