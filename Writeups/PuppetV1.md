# Puppet V1

## Vulnerability

The core vulnerability is that the lending pool uses the **current Uniswap V1 spot price** as its oracle price:

```solidity
uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair)
```

This price is derived directly from the ETH and DVT balances of the Uniswap pair. Since those balances can be changed through normal trades, an attacker can manipulate the spot price and therefore manipulate the collateral required by the lending pool.

## Root Cause

The lending pool trusts a **manipulable AMM spot price** when calculating how much ETH is required to borrow DVT.

The attacker can first trade against Uniswap to change its reserves, causing the DVT price used by the lending pool to fall dramatically.

## Broken Invariant / Assumption

The protocol assumes that the Uniswap spot price accurately represents the economic value of DVT and cannot be cheaply manipulated.

The broken security assumption is:

> **An attacker should not be able to manipulate the oracle price cheaply enough to obtain borrowing power that is not economically justified by their collateral.**

## Attack Path

1. The attacker starts with `1,000 DVT` and `25 ETH`.
2. The attacker sells the DVT into the Uniswap V1 exchange.
3. This increases the DVT reserve and decreases the ETH reserve, causing the DVT/ETH spot price to collapse.
4. The lending pool uses this manipulated spot price when calculating the collateral required to borrow DVT.
5. The attacker calculates the reduced collateral requirement for the entire `100,000 DVT` held by the lending pool.
6. The attacker deposits the required ETH and borrows the entire `100,000 DVT`.
7. The borrowed DVT is sent to the recovery account.
8. Because the price manipulation and borrowing happen within the same transaction, the manipulated price is used immediately.

## Why the Victim Loses Funds

The lending pool determines borrowing requirements using a price that the borrower can directly manipulate through the Uniswap market.

The attacker therefore makes their collateral appear much more valuable relative to the pool's DVT, allowing them to borrow the entire `100,000 DVT` pool with only their available ETH.

## Remediation

Do not use an instantaneous AMM spot price as the sole oracle for determining collateral requirements.

Use a more manipulation-resistant oracle mechanism, such as a **time-weighted price or an independent oracle**, and consider additional safeguards such as price-deviation checks and liquidity/depth considerations.

## Key Lesson

> **A price that is correct according to an AMM's current reserves is not necessarily a trustworthy oracle price.**

A protocol must consider whether an attacker can cheaply manipulate the price it relies on before making economically important decisions.