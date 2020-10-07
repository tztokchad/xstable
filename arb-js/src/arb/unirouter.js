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
const {
  stratAbis,
  STRAT_UNI_ROUTER,
  TOKEN_USDC
} = require("../util/constants");
const { getErc20Decimals, getStrategyContractAddress } = require("../util");
const BigNumber = require("bignumber.js");

function UniRouterArb(web3, arbInstance) {
  const {
    strats,
    profitThreshold,
    gasPrice,
    chainId,
    router1FactoryAddress,
    router1InitCodeHash,
    router2FactoryAddress,
    router2InitCodeHash,
    uniArbPairs
  } = config;
  /**
   * A naive brute forcing arb algo which starts with 1k usdc worth of token2 and
   * checks for arb opps by going token1 -> token2 in router1 and token2 -> token1 in router2
   */
  this.arb = async () => {
    const arbPairs = uniArbPairs.split(",");

    for (let pair of arbPairs) {
      let token1 = pair.split(":")[0];
      let token2 = pair.split(":")[1];

      if (!web3.utils.isAddress(token1) || !web3.utils.isAddress(token2))
        throw new Error(
          `Invalid arb pair: ${pair}. Please check your ARB_PAIRS in .env`
        );

      // Since token2 is not USDC, find usdc price of token2 first before proceeding
      if (token2 !== TOKEN_USDC) {
      }

      // Loop over 10x increments of input amount, starting from 1k USDC until 1m USDC
      let startingCapital = 1000;
      let token1Decimals = await getErc20Decimals(token1);
      let token2Decimals = await getErc20Decimals(token2);
      for (let i = 0; i < 4; i++) {
        let token1ToToken2OutputAmount = new BigNumber(startingCapital)
          .mul(new BigNumber(10).exponentiatedBy(i))
          .mul(new BigNumber(10).exponentiatedBy(token2Decimals))
          .toFixed();

        const token1ToToken2InputAmount = await _getAmountsForUniTrade(
          TradeType.EXACT_OUTPUT,
          token1,
          token2,
          token1ToToken2OutputAmount,
          "inputAmount"
        );
        const token2ToToken1OutputAmount = await _getAmountsForUniTrade(
          TradeType.EXACT_INPUT,
          token2,
          token1,
          token1ToToken2OutputAmount,
          "outputAmount"
        );

        if (
          new BigNumber(token2ToToken1OutputAmount).isGreaterThan(
            new BigNumber(token1ToToken2InputAmount).plus(
              new BigNumber(profitThreshold).mul(10 ** token1Decimals)
            )
          )
        ) {
          // Successful arb opp. Make trade
          await arbInstance.methods
            .initFlashloan(
              token2,
              token1ToToken2OutputAmount,
              getStrategyContractAddress(STRAT_UNI_ROUTER),
              web3.eth.abi.encodeParameters(
                ["uint256", "address", "address", "uint256", "uint256"],
                [
                  token1ToToken2InputAmount,
                  token1,
                  token2,
                  token1ToToken2OutputAmount,
                  token2ToToken1OutputAmount
                ]
              )
            )
            .send({
              gasPrice
            });
        }
      }
    }
  };

  /**
   * Returns output amount for a uni trade between token1 and token2 for a given inputAmount
   * @param _token1 Token 1 address
   * @param _token2 Token 2 address
   * @param _inputAmount Input amount
   * @param _isRouter1 Is this trade happening on router 1
   * @return Token 2 output amount
   */
  const _getAmountsForUniTrade = async (
    _tradeType,
    _token1,
    _token2,
    _amount,
    _amountType,
    _isRouter1
  ) => {
    if (
      _tradeType !== TradeType.EXACT_INPUT &&
      _tradeType !== TradeType.EXACT_OUTPUT
    )
      throw new Error(`Invalid trade type: ${_tradeType}`);
    if (_amountType !== "outputAmount" && _amountType !== "inputAmount")
      throw new Error(`Invalid amount type: ${_amountType}`);
    const token1 = new Token(chainId, _token1, await getErc20Decimals(_token1));
    const token2 = new Token(chainId, _token2, await getErc20Decimals(_token2));
    const pair = await Fetcher.fetchPairData(
      token1,
      token2,
      isRouter1 ? router1FactoryAddress : router2FactoryAddress,
      isRouter1 ? router1InitCodeHash : router2InitCodeHash
    );
    const route = new Route([pair], token2);
    const trade = new Trade(
      route,
      new TokenAmount(token2, _amount),
      _tradeType
    );
    return trade[_amountType].toSignificant(6);
  };
}

module.exports = UniRouterArb;
