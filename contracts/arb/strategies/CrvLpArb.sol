pragma solidity ^0.6.10;

import "./FlashLoanStrategy.sol";

import "../../interface/ICurve.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrvLpArb is FlashLoanStrategy, Ownable {

    using SafeMath for uint256;

    ICurve constant internal curveCompound  = ICurve(0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56);
    ICurve constant internal curveY         = ICurve(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    ICurve constant internal curveBinance   = ICurve(0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27);
    ICurve constant internal curveSynthetix = ICurve(0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
    ICurve constant internal curvePAX       = ICurve(0x06364f10B501e868329afBc005b3492902d6C763);

    ICurve[5] internal curveSwaps = [
      curveCompound,
      curveY,
      curveBinance,
      curveSynthetix,
      curvePAX
    ];

    function execute(
      bytes memory strategyData
    ) 
    override 
    public  {
        (
          address _curveSwap1,
          int128 _swap1_from,
          int128 _swap1_to,
          address _curveSwap2,
          int128 _swap2_from,
          int128 _swap2_to
        ) = abi.decode(
          strategyData, 
          (
            address,
            int128,
            int128,
            address,
            int128,
            int128
          )
        );

      require(_isValidCurveSwap(_curveSwap1), "Invalid swap1 address");
      require(_isValidCurveSwap(_curveSwap2), "Invalid swap2 address");

      require(_isValidSwapCoin(_curveSwap1, _swap1_from), "Invalid swap1 from");
      require(_isValidSwapCoin(_curveSwap1, _swap1_to), "Invalid swap1 to");

      require(_isValidSwapCoin(_curveSwap2, _swap1_from), "Invalid swap2 from");
      require(_isValidSwapCoin(_curveSwap2, _swap1_to), "Invalid swap2 to");

      ICurve curveSwap1 = ICurve(_curveSwap1);
      ICurve curveSwap2 = ICurve(_curveSwap2);
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
        if (address(curveSwaps[i]) == _swap)
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