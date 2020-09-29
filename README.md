# XStable

Stablecoin backed by stablecoins locked into Curve/Swerve DAO.

## Working

XStable allows users to deposit Curve (and curve clone) LP tokens into their respective DAOs while minting XSUSD tokens in return based on the virtual price of the LP token at the time of deposit.

XSUSD can be redeemed at any point in time for LP tokens in the contracts' reserves based on LP token virtual prices at the time of withdrawal.

## Setup

1. `git clone https://github.com/tztokchad/xstable.git`
2. `npm i`

## Testing

`truffle test`