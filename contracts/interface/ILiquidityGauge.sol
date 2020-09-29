pragma solidity ^0.6.10;

interface ILiquidityGauge {
    function deposit(uint256 _value, address addr) external;

    function withdraw(uint256 _value) external;

    function claimable_tokens(address _addr) external view returns (uint256);

    function user_checkpoint(address _addr) external view returns (uint256);

    function lpToken() external view returns (address);
}
