pragma solidity ^0.6.10;

interface IBPool {

  function swapExactAmountIn(address tokenIn, uint tokenAmountIn, address tokenOut, uint minAmountOut, uint maxPrice) external;

}