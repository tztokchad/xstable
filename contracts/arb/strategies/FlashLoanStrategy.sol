pragma solidity ^0.6.10;

abstract contract FlashLoanStrategy {

  function execute(bytes memory strategyData) virtual external;

  function withdrawBalance(address _token) payable virtual external;

}