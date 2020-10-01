pragma solidity ^0.6.10;

import "./FlashLoanStrategy.sol";

contract CrvLpArb is FlashLoanStrategy {

    function execute(
      bytes memory strategyData
    ) 
    override 
    public  {
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

}