pragma solidity ^0.6.10;

import "./FlashLoanStrategy.sol";

import "../../interface/IBPool.sol";
import "../../interface/IUniswapV2Router.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniBalArb is FlashLoanStrategy, Ownable {

    using SafeMath for uint256;

    // Whitelisted uniswap v2 routers
    mapping (address => bool) uniV2Routers;

    event NewUniV2Router(address _router);

    /**
    * Adds uni v2 router to whitelist
    * @param _router UniV2Router address
    */
    function addUniV2Router(address _router) 
    public 
    onlyOwner {
      require(!uniV2Routers[_router], "router already added");
      uniV2Routers[_router] = true;
      emit NewUniV2Router(_router);
    }

    function execute(
      bytes memory strategyData
    ) 
    override 
    public  {
        (
          address router,
          bool isUniToBal,
          uint256 token1In,
          uint256 minToken2Out,
          address token1,
          address token2,
          address bPool,
          uint256 minToken1Out,
          uint256 balMaxPrice
        ) = abi.decode(
          strategyData, 
          (
            address,
            bool,
            uint256,
            uint256,
            address,
            address,
            address,
            uint256,
            uint256
          )
        );

        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(router);

        if (isUniToBal) {
          // Trade 1: Execute swap of token1 into designated token2 on UniswapV2
          try uniswapV2Router.swapExactTokensForTokens(
              token1In, 
              minToken2Out,
              getPathForTokenToToken(token1, token2), 
              address(this), 
              block.timestamp + 300
          ){
          } catch {
              // error handling
          }

          // Trade 1: Execute swap of token2 into designated token1 on Balancer
          try IBPool(bPool).swapExactAmountIn(
            token2,
            IERC20(token2).balanceOf(address(this)),
            token1,
            minToken1Out,
            balMaxPrice
          ) {
          } catch {
              // error handling
          }
        } else {
          // Trade 1: Execute swap of token1 into designated token2 on Balancer
          try IBPool(bPool).swapExactAmountIn(
            token1,
            token1In,
            token2,
            minToken2Out,
            balMaxPrice
          ) {
          } catch {
              // error handling
          }

          // Trade 2: Execute swap of token2 into designated token1 on UniswapV2
          try uniswapV2Router.swapExactTokensForTokens(
              IERC20(token2).balanceOf(address(this)), 
              minToken2Out,
              getPathForTokenToToken(token2, token1), 
              address(this), 
              block.timestamp + 300
          ){
          } catch {
              // error handling
          }
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