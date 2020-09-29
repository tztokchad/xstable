pragma solidity ^0.6.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "./token/XSUSD.sol";

import "./interface/ILiquidityGauge.sol";
import "./interface/ICurve.sol";

contract XStable is Ownable {

    using SafeMath for uint256;

    XSUSD public xsUsd;

    /** Swap addresses **/
    ICurve constant internal curveCompound  = ICurve(0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56);
    ICurve constant internal curveY         = ICurve(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    ICurve constant internal curveBinance   = ICurve(0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27);
    ICurve constant internal curveSynthetix = ICurve(0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
    ICurve constant internal curvePAX       = ICurve(0x06364f10B501e868329afBc005b3492902d6C763);

    ICurve constant internal swerveUSD      = ICurve(0x329239599afB305DA0A2eC69c58F8a6697F9F88d);

    /** Gauge addresses **/
    ILiquidityGauge constant internal curveCompoundGauge  = ILiquidityGauge(0x7ca5b0a2910B33e9759DC7dDB0413949071D7575);
    ILiquidityGauge constant internal curveYGauge         = ILiquidityGauge(0xFA712EE4788C042e2B7BB55E6cb8ec569C4530c1);
    ILiquidityGauge constant internal curveBinanceGauge   = ILiquidityGauge(0x69Fb7c45726cfE2baDeE8317005d3F94bE838840);
    ILiquidityGauge constant internal curveSynthetixGauge = ILiquidityGauge(0xA90996896660DEcC6E997655E065b23788857849);
    ILiquidityGauge constant internal curvePAXGauge       = ILiquidityGauge(0x64E3C23bfc40722d3B649844055F1D51c1ac041d);

    ILiquidityGauge constant internal swerveGauge         = ILiquidityGauge(0xb4d0C929cD3A1FbDc6d57E7D3315cF0C4d6B4bFa);

    // Emitted on depositing lp tokens and minting XSUSD
    event Deposit(
      address sender,
      uint256 amount,
      uint256 mintedXSUsd
    );

    // Emitted on withdrawing lp tokens and burning XSUSD
    event Withdraw(
      address sender,
      uint256 amount,
      uint256 burnedXSUsd
    );

    // Maps swap addresses to gauges
    mapping (address => ILiquidityGauge) public swapGauges;

    constructor()
    public {
        xsUsd = new XSUSD();
        // Curve
        swapGauges[address(curveCompound)]  = curveCompoundGauge;
        swapGauges[address(curveY)]         = curveYGauge;
        swapGauges[address(curveBinance)]   = curveBinanceGauge;
        swapGauges[address(curveSynthetix)] = curveSynthetixGauge;
        swapGauges[address(curvePAX)]       = curvePAXGauge;
        // Swerve
        swapGauges[address(swerveUSD)]      = swerveGauge;
    }

    /**
    * Deposit LP tokens and receive XSUsd based on current virtual price of LP token
    * @param _swap Address of Curve/Swerve swap contract
    * @param _amount Amount of LP tokens to deposit
    * @return mintableXSUSDInWei Number of XSUSD minted
    */
    function deposit(
        address _swap,
        uint256 _amount
    )
    public
    returns (uint256 mintableXSUSDInWei) {
        ILiquidityGauge gauge = swapGauges[_swap];
        require(address(gauge) != address(0), "Invalid swap address");

        // Amount must be > 0
        require(_amount > 0, "_amount == 0");

        // Get the LP token used for this pool gauge
        IERC20 lpToken = IERC20(gauge.lpToken());

        // Check if user has set allowance for XStable to deposit to gauge on users' behalf
        require(lpToken.allowance(msg.sender, address(this)) >= _amount, "allowance < _amount");

        // Transfer lpToken to XStable
        require(lpToken.transferFrom(msg.sender, address(this), _amount), "Error with token transfer");

        // Retrieve the virtual price for this lp token
        uint256 virtualPrice = ICurve(_swap).get_virtual_price();

        // Amount of XSUsd tokens to mint in wei = amount of lp tokens to deposit * virtual price
        mintableXSUSDInWei = _amount.mul(virtualPrice).div(10 ** 18);

        // Mint `mintableXSUSDInWei` XSUSD for msg.sender
        require(xsUsd.mint(msg.sender, mintableXSUSDInWei), "Error minting XSUSD");

        // Emit deposit event
        emit Deposit(
          msg.sender,
          _amount,
          mintableXSUSDInWei
        );
    }

    /**
    * Withdraw XSUsd in LP tokens based on current virtual price of LP token and reserves available in XStable
    * @param _swap Address of Curve/Swerve swap contract
    * @param _amount Amount of LP tokens to withdraw
    */
    function withdraw(
        address _swap,
        uint256 _amount
    )
    public
    returns (uint256 lpTokensWithdrawn) {
        ILiquidityGauge gauge = swapGauges[_swap];
        require(address(gauge) != address(0), "Invalid swap address");

        // Amount must be > 0
        require(_amount > 0, "_amount == 0");

        // Get LP token used for this pool gauge
        IERC20 lpToken = IERC20(gauge.lpToken());

        // Retrieve the virtual price for this lp token
        uint256 virtualPrice = ICurve(_swap).get_virtual_price();

        // Check if user has set allowance for XStable to burn xsUsd on users' behalf
        require(xsUsd.allowance(msg.sender, address(this)) >= _amount, "allowance < _amount");

        // Calculate withdrawable lp tokens based on virtual price
        uint256 withdrawableLpTokens = _amount.mul(10**18).div(virtualPrice).div(10**18);

        // Calculate max withdrawable lp tokens based on virtual price
        uint256 maxWithdrawableLpTokens = IERC20(lpToken).balanceOf(address(this)).mul(10**18).div(virtualPrice).div(10**18);

        lpTokensWithdrawn = withdrawableLpTokens;

        // Number of withdrawable lp tokens cannot be more than max withdrawable lp tokens
        require(
          withdrawableLpTokens <= maxWithdrawableLpTokens, 
          "withdrawableLpTokens > maxWithdrawableLpTokens"
        );

        // Transfer lp tokens to user and burn XSUSD
        require(
          IERC20(lpToken).transfer(msg.sender, withdrawableLpTokens),
          "Error transferring lp tokens"
        );

        // Burn xsUsd from user
        require(
          xsUsd.burnFrom(msg.sender, _amount), 
          "Error with xsUsd burn from user"
        );

        // Emit withdraw event
        emit Withdraw(
          msg.sender,
          _amount,
          withdrawableLpTokens
        );
    }



}
