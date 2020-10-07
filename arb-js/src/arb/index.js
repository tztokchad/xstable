const { 
  ChainId, 
  Token, 
  TokenAmount, 
  WETH, 
  Fetcher, 
  Router, 
  Trade, 
  TradeType
 } = require("@uniswap/sdk");
 const UniRouter = require('./unirouter')

const {
  STRAT_CRV_LP,
  STRAT_UNI_BAL,
  STRAT_UNI_SUSHI,
  STRAT_LIST,
  ARB_SRC_TYPE_BAL,
  ARB_SRC_TYPE_CRV,
  ARB_SRC_TYPE_UNI,
  stratAbis,
  abi_erc20,
  abi_arb,
  TOKEN_USDC
} = require("../util/constants");

function Arb(web3, events, config) {
  const { strats, profitThreshold, gasPrice, chainId, router1, router2, uniArbPairs } = config;
  let arbInstance;
  let uniRouter;

  /**
   * Initalizes arbitrage strategies
   */
  this.arb = async () => {
    uniRouter = new UniRouter(web3, _getArbContractInstance());
    events.subscribeToNewBlocks()
      .on("connected", subscriptionId => console.log('Listening to block headers'))
      .on("data", blockHeader => {
        for (let strat of strats) {
          if (!isValidStrat(strat))
            throw new Error(`Invalid strat: ${strat}. Please update STRAT_LIST`)
          
          if (strat === STRAT_UNI_SUSHI)
            await uniRouter.arb();
        }
      })
      .on("error", console.error("Error receiving new blocks"))
  };

  /**
   * Returns the last price for a given token 1 -> token 2 given the source contract and it's type
   * @param _src Source contract
   * @param _type Type of contract
   * @param _token1 Address of token 1
   * @param _token2 Address of token 2
   * @param _inputAmount Input token amount
   * @return Last price for token1 -> token2 trade
   */
  const _getLastPrice = async (_src, _type, _token1, _token2, _inputAmount) => {
    if (_type === ARB_SRC_TYPE_BAL) {
      return _src.methods.getSpotPrice(token1, token2).call();
    } else if (_type === ARB_SRC_TYPE_UNI) {
      const token1 = new Token(chainId, _token1, await _getErc20Decimals(_token1));
      const token2 = new Token(chainId, _token2, await _getErc20Decimals(_token2));
      const pair = await Fetcher.fetchPairData(token1, token2);
      const route = new Route([pair], token2);
      const trade = new Trade(route, new TokenAmount(token2, _inputAmount), TradeType.EXACT_OUTPUT);
      return trade.executionPrice.toSignificant(6);
    } else if (_type === ARB_SRC_TYPE_CRV) {
      const underlyingAddresses = await _getUnderlyingCurveCoinAddresses(_src)
      return await _src.methods.get_dy_underlying(
        underlyingAddresses[_token1],
        underlyingAddresses[_token2],
        _inputAmount
      )
    }
  };

  /**
   * Returns available underlying coins for a given source Curve contract
   * @param {*} _crv Curve contract
   * @return Object mapping curve underlying coin addresses to their indices
   */
  const _getUnderlyingCurveCoinAddresses = _crv => {
    let _isEndOfCoins = false
    let index = 0
    let coins = {}
    while (!_isEndOfCoins) {
      try {
        let address = await _crv.methods.underlying_coins(index).call()
        coins[address] = index++
      } catch (e) {
        _isEndOfCoins = true
      }
    }
    return coins
  }

  /**
   * Returns an Arb contract instance
   * @return Initalized Arb contract
   */
  const _getArbContractInstance = () => {
    if (!arbInstance)
      arbInstance = new web3.eth.Contract(abi_arb, abi_arb.networks[chainId].address);
    return arbInstance;
  }

}

module.exports = Arb;
