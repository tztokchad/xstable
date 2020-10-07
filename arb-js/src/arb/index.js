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
const BigNumber = require("bignumber.js");

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

  /**
   * Initalizes arbitrage strategies
   */
  this.arb = async () => {
    events.subscribeToNewBlocks()
      .on("connected", subscriptionId => console.log('Listening to block headers'))
      .on("data", blockHeader => {
        for (let strat of strats) {
          if (!isValidStrat(strat))
            throw new Error(`Invalid strat: ${strat}. Please update STRAT_LIST`)
          
          if (strat === STRAT_UNI_SUSHI)
            await _arbUniRouters()
        }
      })
      .on("error", console.error("Error receiving new blocks"))
  };

  /**
   * A naive brute forcing arb algo which starts with 1k usdc worth of token2 and 
   * checks for arb opps by going token1 -> token2 in router1 and token2 -> token1 in router2
   */
  const _arbUniRouters = async () => {
    // From and to ABIs are the same
    const abi = _getStratAbis(STRAT_UNI_SUSHI).from;
    const router1 = new web3.eth.Contract(abi, router1)
    const router2 = new web3.eth.Contract(abi, router2)
    
    const arbPairs = uniArbPairs.split(',')

    for (let pair of arbPairs) {
      let token1 = pair.split(':')[0]
      let token2 = pair.split(':')[1]

      if (!web3.utils.isAddress(token1) || !web3.utils.isAddress(token2))
        throw new Error(`Invalid arb pair: ${pair}. Please check your ARB_PAIRS in .env`)

      // Since token2 is not USDC, find usdc price of token2 first before proceeding
      if (token2 !== TOKEN_USDC) {

      }

      // Loop over 10x increments of input amount, starting from 1k USDC until 1m USDC
      let startingCapital = 1000
      for (let i = 0; i < 4; i++) {
        let token2Decimals = await _getErc20Decimals(token2)
        let token1ToToken2OutputAmount = 
          new BigNumber(startingCapital)
          .mul(new BigNumber(10).exponentiatedBy(i))
          .mul(new BigNumber(10).exponentiatedBy(token2Decimals))
          .toFixed();  

        const token1ToToken2InputAmount = 
          await _getAmountsForUniTrade(
            TradeType.EXACT_OUTPUT, 
            token1, 
            token2, 
            token1ToToken2OutputAmount, 
            'inputAmount'
          );
        const token2ToToken1OutputAmount = 
          await _getAmountsForUniTrade(
            TradeType.EXACT_INPUT,
            token2,
            token1,
            token1ToToken2OutputAmount,
            'outputAmount'
          );

        if (new BigNumber(token2ToToken1OutputAmount).isGreaterThan(token1ToToken2InputAmount)) {
          // Successful arb opp. Make trade
          await arb.methods.initFlashloan(
            token2,
            token1ToToken2OutputAmount,
            _getStrategyContractAddress(STRAT_UNI_SUSHI),
            web3.eth.abi.encodeParameters([
              'uint256', 
              'address', 
              'address', 
              'uint256', 
              'uint256'
            ], [
              token1ToToken2InputAmount,
              token1,
              token2,
              token1ToToken2OutputAmount,
              token2ToToken1OutputAmount
            ])
          ).send({
            gasPrice
          });
        }
      }
    }
  }

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
   * Returns output amount for a uni trade between token1 and token2 for a given inputAmount
   * @param _token1 Token 1 address
   * @param _token2 Token 2 address
   * @param _inputAmount Input amount
   * @return Token 2 output amount 
   */
  const _getAmountsForUniTrade = async (_tradeType, _token1, _token2, _amount, _amountType) => {
    if (_tradeType !== TradeType.EXACT_INPUT && _tradeType !== TradeType.EXACT_OUTPUT)
      throw new Error(`Invalid trade type: ${_tradeType}`);
    if (_amountType !== 'outputAmount' && _amountType !== 'inputAmount')
      throw new Error(`Invalid amount type: ${_amountType}`);
    const token1 = new Token(chainId, _token1, await _getErc20Decimals(_token1));
    const token2 = new Token(chainId, _token2, await _getErc20Decimals(_token2));
    const pair = await Fetcher.fetchPairData(token1, token2);
    const route = new Route([pair], token2);
    const trade = new Trade(route, new TokenAmount(token2, _amount), _tradeType);
    return trade[_amountType].toSignificant(6);
  }

  /**
   * Returns decimals for a given erc20 token
   * @param _addr Address of ERC20 token
   */
  const _getErc20Decimals = _addr => (new web3.eth.Contract(abi_erc20, _addr)).methods.decimals().call()

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
   * Returns whether given strategy is part of available strategies
   * @param strat Strategy name
   * @return Whether strategy is valid
   */
  const _isValidStrat = _strat => STRAT_LIST.indexOf(_strat) !== -1

  /**
   * Returns from/to contract ABIs for a strat
   * @param strat Strategy name
   * @return From/to contract ABIs
   */
  const _getStratAbis = _strat => stratAbis[_strat]

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
