pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "./dydx/DyDxFlashLoan.sol";

import "./arb/strategies/FlashLoanStrategy.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Arb is DyDxFlashLoan, Ownable {

    using SafeMath for uint256;
    uint256 public loan;
    uint deadline;

    mapping (address => bool) flashLoanStrategies;

    event NewFlashLoanStrategy(address _strategy);
    
    /**
        Initialize deployment parameters
     */
    constructor ()
    public 
    payable {
      // setting deadline to avoid scenario where miners hang onto it and execute at a more profitable time
      deadline = block.timestamp + 300; // 5 minutes
    }

    function addFlashLoanStrategy(address _strategy)
    public
    onlyOwner {
      require(!flashLoanStrategies[_strategy], "Strategy already exists");

      flashLoanStrategies[_strategy] = true;

      emit NewFlashLoanStrategy(address(_strategy));
    }

    function initFlashloan(
      address _flashToken,
      uint256 _flashAmount,
      address _strategy,
      bytes memory strategyData
    ) 
    external
    onlyOwner {
        uint256 balanceBefore = IERC20(_flashToken).balanceOf(address(this));

        require(flashLoanStrategies[_strategy], "Invalid flashloan strategy");

        bytes memory flashLoanData = abi.encode(_flashToken, _flashAmount, balanceBefore, _strategy, strategyData); 

        flashloan(_flashToken, _flashAmount, flashLoanData); // execution goes to `callFunction`
        // and at this point we have succefully paid the debt
    }

    function callFunction(
        address, /* sender */
        Info calldata, /* accountInfo */
        bytes calldata flashLoanData
    ) external onlyPool {
        (
          address flashToken, 
          uint256 flashAmount,
          uint256 balanceBefore, 
          address strategy, 
          bytes memory strategyData
        ) = abi
            .decode(flashLoanData, (address, uint256, uint256, address, bytes));
        uint256 balanceAfter = IERC20(flashToken).balanceOf(address(this));
        require(
            balanceAfter - balanceBefore == flashAmount,
            "contract did not get the loan"
        );
        loan = balanceAfter;

        // execute arbitrage strategy
        try FlashLoanStrategy(strategy).execute(strategyData) {
          FlashLoanStrategy(strategy).withdrawBalance(flashToken);
        } catch Error(string memory) {
            // Reverted with a reason string provided
        } catch (bytes memory) {
            // failing assertion, division by zero.. blah blah
        }
        // the debt will be automatically withdrawn from this contract at the end of execution
    }
}