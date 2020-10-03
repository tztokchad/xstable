pragma solidity ^0.6.10;

import "./FlashLoanStrategy.sol";

import "../../interface/ICurve.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrvLpArb is FlashLoanStrategy, Ownable {

    using SafeMath for uint256;

    address[] public curveSwaps;

    // Whitelisted curve swap addresses
    mapping (address => bool) whitelistedCurveSwaps;

    event NewWhitelistedSwap(address _swap);

    /**
    * Adds a new curve swap address to whitelist
    * @param _swap Curve swap address
    */
    function addCurveSwap(address _swap)
    public
    onlyOwner {
      require(!whitelistedCurveSwaps[_swap], "swap already whitelisted");
      whitelistedCurveSwaps[_swap] = true;
      curveSwaps.push(_swap);
      
      emit NewWhitelistedSwap(_swap);
    }

    function execute(
      bytes memory strategyData
    ) 
    override 
    public  {
        (
          address _curveSwap1,
          int128 _swap_from,
          int128 _swap_to,
          uint256 _swap1_dx,
          uint256 _swap1_min_dy,
          address _curveSwap2,
          uint256 _swap2_min_dy
        ) = abi.decode(
          strategyData, 
          (
            address,
            int128,
            int128,
            uint256,
            uint256,
            address,
            uint256
          )
        );

      require(_isValidCurveSwap(_curveSwap1), "Invalid swap1 address");
      require(_isValidCurveSwap(_curveSwap2), "Invalid swap2 address");

      require(_isValidSwapCoin(_curveSwap1, _swap_from), "Invalid swap from");
      require(_isValidSwapCoin(_curveSwap1, _swap_to), "Invalid swap to");

      ICurve curveSwap1 = ICurve(_curveSwap1);
      ICurve curveSwap2 = ICurve(_curveSwap2);

      // Complete swap1 
      curveSwap1.exchange_underlying(
        _swap_from,
        _swap_to,
        _swap1_dx,
        _swap1_min_dy
      );

      // Complete swap2
      curveSwap2.exchange_underlying(
        _swap_to,
        _swap_from,
        IERC20(curveSwap2.coins(_swap_to)).balanceOf(address(this)),
        _swap2_min_dy
      );
    }

    /**
    * Returns whether a provided address is a valid curve swap address
    * @param _swap Curve swap address
    * @return Whether swap address is valid
    */
    function _isValidCurveSwap(address _swap)
    public
    view
    returns (bool) {
      for (uint8 i = 0; i < curveSwaps.length; i++) {
        if (curveSwaps[i] == _swap)
          return true;
      }
      return false;
    }

    /**
    * Returns whether a provided coin for a curve swap address is valid
    * @param _swap Curve swap address
    * @param _coin Coin index
    * @return Whether coin is valid for swap address
    */
    function _isValidSwapCoin(address _swap, int128 _coin)
    public
    view
    returns (bool) {
      return ICurve(_swap).coins(_coin) != address(0);
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