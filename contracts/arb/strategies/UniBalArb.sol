pragma solidity ^0.6.10;

import "./FlashLoanStrategy.sol";

import "../../interface/IBPool.sol";
import "../../interface/IUniswapV2Router.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniBalArb is FlashLoanStrategy, Ownable {

    using SafeMath for uint256;
    IUniswapV2Router02 uniswapV2Router;
    
    /**
        Initialize deployment parameters
     */
    constructor (
        IUniswapV2Router02 _uniswapV2Router
    )
    public {
      // instantiate SushiswapV1 and UniswapV2 Router02
      uniswapV2Router = IUniswapV2Router02(address(_uniswapV2Router));
    }

    function execute(
      bytes memory strategyData
    ) 
    override 
    public  {
        (
          uint256 uniTokensIn,
          uint256 uniMinTokensOut,
          address token1,
          address token2,
          address bPool,
          uint256 balMinTokensOut,
          uint256 balMaxPrice
        ) = abi.decode(
          strategyData, 
          (
            uint256,
            uint256,
            address,
            address,
            address,
            uint256,
            uint256
          )
        );

        // Trade 1: Execute swap of token1 into designated token2 on UniswapV2
        try uniswapV2Router.swapExactTokensForTokens(
            uniTokensIn, 
            uniMinTokensOut,
            getPathForTokenToToken(token1, token2), 
            address(this), 
            block.timestamp + 300
        ){
        } catch {
            // error handling
        }

        try IBPool(bPool).swapExactAmountIn(
          token2,
          IERC20(token2).balanceOf(address(this)),
          token1,
          balMinTokensOut,
          balMaxPrice
        ) {
        } catch {
             // error handling
        }
    }

    /**
    * Sweep entire balance on the arb contract back to contract owner
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

}