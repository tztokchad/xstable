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

import "./dydx/DyDxFlashLoan.sol";

// importing both Sushiswap V1 and Uniswap V2 Router02 dependencies
import "./interface/IUniswapV2Router.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Arb is DyDxFlashLoan, Ownable {

    using SafeMath for uint256;
    IUniswapV2Router02 uniswapV2Router;
    IUniswapV2Router02 sushiswapV1Router;
    uint256 public loan;
    uint deadline;
    IERC20 dai = IERC20(DAI);
    uint256 amountToTrade;
    uint256 tokensOut;
    
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

    function getFlashloan(
      address _flashToken,
      uint256 _flashAmount,
      uint _amountToTrade,
      uint256 _tokensOut
    ) external {
        uint256 balanceBefore = IERC20(_flashToken).balanceOf(address(this));
        bytes memory data = abi.encode(_flashToken, _flashAmount, balanceBefore);
        
        amountToTrade = _amountToTrade; // how much wei you want to trade
        tokensOut = _tokensOut; // how many tokens you want converted on the return trade     

        flashloan(_flashToken, _flashAmount, data); // execution goes to `callFunction`
        // and at this point we have succefully paid the debt
    }

    function callFunction(
        address, /* sender */
        Info calldata, /* accountInfo */
        bytes calldata data
    ) external onlyPool {
        (address flashToken, uint256 flashAmount, uint256 balanceBefore) = abi
            .decode(data, (address, uint256, uint256));
        uint256 balanceAfter = IERC20(flashToken).balanceOf(address(this));
        require(
            balanceAfter - balanceBefore == flashAmount,
            "contract did not get the loan"
        );
        loan = balanceAfter;

        // execute arbitrage strategy
        try this.executeArbitrage() {
        } catch Error(string memory) {
            // Reverted with a reason string provided
        } catch (bytes memory) {
            // failing assertion, division by zero.. blah blah
        }
        // the debt will be automatically withdrawn from this contract at the end of execution
    }

    /**
        The specific cross protocol swaps that makes up your arb strategy
        UniswapV2 -> SushiswapV1 example below
     */
    function executeArbitrage() public {
        // Trade 1: Execute swap of Ether into designated ERC20 token on UniswapV2
        try uniswapV2Router.swapETHForExactTokens{ 
            value: amountToTrade 
        }(
            amountToTrade, 
            getPathForETHToToken(DAI), 
            address(this), 
            deadline
        ){
        } catch {
            // error handling when arb failed due to trade 1
        }
        
        uint256 tokenAmountInWEI = tokensOut.mul(10 ** 18); //convert into Wei
        uint256 estimatedETH = getEstimatedETHForToken(tokensOut, DAI)[0]; // check how much ETH you'll get for x number of ERC20 token
        
        // grant uniswap / sushiswap access to your token, DAI used since we're swapping DAI back into ETH
        dai.approve(address(uniswapV2Router), tokenAmountInWEI);
        dai.approve(address(sushiswapV1Router), tokenAmountInWEI);

        // Trade 2: Execute swap of the ERC20 token back into ETH on Sushiswap to complete the arb
        try sushiswapV1Router.swapExactTokensForETH (
            tokenAmountInWEI, 
            estimatedETH, 
            getPathForTokenToETH(DAI), 
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
    function WithdrawBalance() public payable onlyOwner {
        // withdraw all ETH
        msg.sender.call{ value: address(this).balance }("");
        // withdraw all x ERC20 tokens
        dai.transfer(msg.sender, dai.balanceOf(address(this)));
    }

    /**
        Using a WETH wrapper here since there are no direct ETH pairs in Uniswap v2
        and sushiswap v1 is based on uniswap v2
     */
    function getPathForETHToToken(address ERC20Token) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = ERC20Token;
    
        return path;
    }

    /**
        Using a WETH wrapper to convert ERC20 token back into ETH
     */
     function getPathForTokenToETH(address ERC20Token) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = ERC20Token;
        path[1] = sushiswapV1Router.WETH();
        
        return path;
    }

    /**
        helper function to check ERC20 to ETH conversion rate
     */
    function getEstimatedETHForToken(uint _tokenAmount, address ERC20Token) public view returns (uint[] memory) {
        return uniswapV2Router.getAmountsOut(_tokenAmount, getPathForTokenToETH(ERC20Token));
    }
}