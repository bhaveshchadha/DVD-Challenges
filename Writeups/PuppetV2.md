# Puppet V2

## Vulnerability
Same as V1 , depends on the derives the DVT/WETH price provided by UniswapV2 Pair reserves, which depends upon balance of dvt and weth of the pair itself, these balances can be changed through normal trades , hence allowing attacker to control the price

## Root Cause
The lending pool trusts a **manipulable AMM spot price** when calculating how much ETH is required to borrow DVT.

The attacker can first trade against Uniswap to change its reserves, causing the DVT price used by the lending pool to fall dramatically.
## Broken Invariant / Assumption
This protocol assumes that replace v1 exchanges with v2 pair systems prevents attacker from manipulating attack

The protocol assumes that the current Uniswap V2 reserve-based price is sufficiently reliable for determining collateral requirements, even though an attacker can cheaply manipulate the Pair's reserves before borrowing.


## Attack Path

1. First attacker sells his 20 eth for 20 weth
2. then sells his 10,000 dvt and gets 9.9 weth 
3. Pool initially had 100 dvt and 10 weth, now has 10,100 dvt and 0.1 weth
4. so new price becomes 1 DVT =0.000009803 WETH from 0.1 WETH according to the reserve ratio used by the vulnerable oracle
5. So now Player has 29.9 weth , in exchange of 29.4 weth as collateral he can borrow 1 m dvt
6. he borrows 1m dvt and sends it to recovery account

## Why the Victim Loses Funds
The lending pool determines borrowing requirements using a price that the borrower can directly manipulate through the Uniswap market.

The attacker therefore makes their collateral appear much more valuable relative to the pool's DVT, allowing them to borrow the entire `100,0000 DVT` pool with only their available WETH.

## Remediation
Do not use an instantaneous AMM spot price as the sole oracle for determining collateral requirements.

Use a more manipulation-resistant oracle mechanism, such as a **time-weighted price or an independent oracle**, and consider additional safeguards such as price-deviation checks and liquidity/depth considerations.

## Key Lesson
> **A price that is correct according to an AMM's current reserves is not necessarily a trustworthy oracle price.**

A protocol must consider whether an attacker can cheaply manipulate the price it relies on before making economically important decisions.