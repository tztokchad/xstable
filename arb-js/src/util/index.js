/**
 * Returns decimals for a given erc20 token
 * @param _addr Address of ERC20 token
 */
const getErc20Decimals = (web3, _addr) =>
  new web3.eth.Contract(abi_erc20, _addr).methods.decimals().call();

/**
 * Returns contract address for strategy for given chain ID
 * @param {*} strat Strategy name
 * @param chainId Chain ID
 * @return Address of strategy contract for chain ID
 */
const getStrategyContractAddress = (strat, chainId) => "0x";

module.exports = {
  getErc20Decimals,
  getStrategyContractAddress
};
