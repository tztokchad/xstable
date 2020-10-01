pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

// Source: https://github.com/fifikobayashi/Flash-Arb-Trader

/**
    Ropsten instances: 
    - Uniswap V2 Router:                    0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    - Sushiswap V1 Router:                  No official sushi routers on testnet
    - DAI:                                  0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108
    - ETH:                                  0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    
    Mainnet instances:
    - Uniswap V2 Router:                    0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    - Sushiswap V1 Router:                  0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F
    - DAI:                                  0x6B175474E89094C44Da98b954EedeAC495271d0F
    - ETH:                                  0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
*/

import "./FlashLoanStrategy.sol";

// importing both Sushiswap V1 and Uniswap V2 Router02 dependencies
import "../../interface/IUniswapV2Router.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniSushiArb is FlashLoanStrategy, Ownable {

    using SafeMath for uint256;
    IUniswapV2Router02 uniswapV2Router;
    IUniswapV2Router02 sushiswapV1Router;
    uint deadline;
    
    /**
        Initialize deployment parameters
     */
    constructor (
        IUniswapV2Router02 _uniswapV2Router, 
        IUniswapV2Router02 _sushiswapV1Router
    )
    public 
    payable {
      // instantiate SushiswapV1 and UniswapV2 Router02
      sushiswapV1Router = IUniswapV2Router02(address(_sushiswapV1Router));
      uniswapV2Router = IUniswapV2Router02(address(_uniswapV2Router));

      // setting deadline to avoid scenario where miners hang onto it and execute at a more profitable time
      deadline = block.timestamp + 300; // 5 minutes
    }

    /**
        The specific cross protocol swaps that makes up your arb strategy
        UniswapV2 -> SushiswapV1 example below
     */
    function execute(
      bytes memory strategyData
    ) 
    override 
    public  {
        (uint256 tokensIn, address token1, address token2, uint256 tokensOut1, uint256 tokensOut2) = abi
            .decode(strategyData, (uint256, address, address, uint256, uint256));
        // Trade 1: Execute swap of token1 into designated token2 on UniswapV2
        try uniswapV2Router.swapExactTokensForTokens(
            tokensIn, 
            tokensOut1,
            getPathForTokenToToken(token1, token2), 
            address(this), 
            deadline
        ){
        } catch {
            // error handling when arb failed due to trade 1
        }
        
        uint256 tokenAmountInWEI = tokensOut2.mul(10 ** 18); //convert into Wei
        uint256 estimateToken = getEstimatedTokenForToken(tokensOut2, token1, token2)[0]; // check how much token2 you'll get for x number of token1
        
        // grant uniswap / sushiswap access to your token, DAI used since we're swapping DAI back into ETH
        IERC20(token2).approve(address(uniswapV2Router), tokenAmountInWEI);
        IERC20(token2).approve(address(sushiswapV1Router), tokenAmountInWEI);

        // Trade 2: Execute swap of the ERC20 token back into ETH on Sushiswap to complete the arb
        try sushiswapV1Router.swapExactTokensForTokens (
            tokenAmountInWEI, 
            estimateToken, 
            getPathForTokenToToken(token1, token2), 
            address(this), 
            deadline
        ){
        } catch {
            // error handling when arb failed due to trade 2    
        }
    }

    /**
        sweep entire balance on the arb contract back to contract owner
     */
    function withdrawBalance(address _token) 
    public 
    payable
    override
    onlyOwner {
        // withdraw all ETH
        msg.sender.call{ value: address(this).balance }("");
        // withdraw all x ERC20 tokens
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }

    /**
        Using a WETH wrapper here since there are no direct ETH pairs in Uniswap v2
        and sushiswap v1 is based on uniswap v2
     */
    function getPathForTokenToToken(
      address _token1, 
      address _token2
    ) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = _token1;
        path[1] = _token2;
    
        return path;
    }

    /**
        helper function to check ERC20 to ETH conversion rate
     */
    function getEstimatedTokenForToken(uint _tokenAmount, address _token1, address _token2) public view returns (uint[] memory) {
        return uniswapV2Router.getAmountsOut(_tokenAmount, getPathForTokenToToken(_token1, _token2));
    }
}