# XStable

Stablecoin backed by stablecoins locked into Curve/Swerve DAO.

## Working

The XStable contract allows users to deposit Curve (and clone) LP tokens into DAOs and mints XSUsd tokens in return based on the virtual price of the LP token.

XSUsd can be redeemed at any point in time for LP tokens in reserve based on the virtual price of these tokens at the time of withdrawal.

## Setup

1. `git clone https://github.com/tztokchad/xstable.git`
2. `npm i`

## Testing

`truffle test`