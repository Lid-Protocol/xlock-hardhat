# xLock/xEth
xLock is an open, 0 fee defi platform for infinite locked liquidity. Forked from uLock, inspired by rootkit.

##Dapp
https://xlock.eth.link
Connect with Metamask, then launch your new token with as much xETH liquidity as you like. Or exchange xETH for ETH at a 1:1 ratio. All circulating xEth is backed 1:1 by ETH.

## Contract deployments
### Mainnet
xeth: `0x29B109625ac15BC4577d0b70ACB9e4E27F7C07E8`
xlocker proxy: `0xAA13f1Fc73baB751Da08930007D4D847EeEafAA2`
xethLiq proxy: ``

### Ropsten
xeth: `0xA2F864C1c1a27f257c10FfBCFAeCa252B5610B4b`
xlocker proxy: `0x45a0A95Df3DAE8A9741328a0b7ce04DF55C22124`
xethLiq proxy: `0x24a20012D9D1c4f62De50f89cDb7eDDf37385DF5`


## Installation
1. `npm install`
2. Copy `keys-COPY.json` to `keys.json` and fill out the fields.
3. `npm run build`

You can then deploy with `npm deploy-[NETWORK]` for either ropsten or mainnet. For upgrading, use `npm upgrade-[NETWORK]`.

If upgrading contracts, you will need to (1) use the admin key for the contract you deployed (2) edit the `const XlockerAddress`in scripts/upgrade.js.