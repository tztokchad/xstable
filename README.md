# XStable

Stablecoin backed by stablecoins locked into Curve/Swerve DAO. This allows for 3 layers of rewards (and maximum APRs) - Curve LP, DAO and XST (XStable Token) Farming.

## Working

XStable allows users to deposit Curve (and curve clone) LP tokens into their respective DAOs while minting XSUSD tokens in return based on the virtual price of the LP token at the time of deposit.

XSUSD can be redeemed at any point in time for LP tokens in the contracts' reserves based on LP token virtual prices at the time of withdrawal.

CRV, SWRV, SNOW rewards are claimed and insta-sold on uniswap/sushiswap for USDC. The resulting USDC is claimable by users based on their % of the XSUSD supply coupled with how long the XSUSD was held.

XSUSD while being ERC20s, have a couple of additional functions such as `transferWithReward()` which allows users to transfer tokens along with their share of claimable rewards to the receiver. 

This allows for XSUSD to be staked in yield farming contracts without worrying about claimable USD rewards during the duration of being locked being lost by the original owner.

## Setup

1. `git clone https://github.com/tztokchad/xstable.git`
2. `npm i`

## Testing

`truffle test`