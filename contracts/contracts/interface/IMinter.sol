pragma solidity ^0.6.10;

interface IMinter {
  function mint(address gauge_addr) external;

  function mint_many(address[8] memory gauge_addrs) external;

}
