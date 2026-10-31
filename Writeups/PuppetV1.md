# Puppet V1

## Vulnerability

The lending pool uses the current Uniswap V1 spot price as its oracle price:

```solidity
uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair)
```

This price is calculated directly from the ETH and DVT reserves of the Uniswap pair. Since these reserves can be manipulated through trades, an attacker can manipulate the spot price and, consequently, the collateral required by the lending pool.

## Root Cause

The lending pool trusts a manipulable AMM spot price when calculating how much ETH is required to borrow DVT.

An attacker can trade against Uniswap to change its reserves, causing the DVT price used by the lending pool to fall dramatically.

## Broken Invariant / Assumption

**Invariant**

The protocol should not allow an attacker to manipulate the oracle price cheaply enough to obtain borrowing power that is not economically justified by their collateral.

**Violation**

The lending pool assumes that the Uniswap spot price accurately represents the economic value of DVT and cannot be cheaply manipulated. However, an attacker can alter the exchange's reserves through trades, manipulating the price used to determine collateral requirements.

## Attack Path

1. **Prepare initial funds:** The attacker starts with `1,000 DVT` and `25 ETH`.
2. **Manipulate the Uniswap price:** The attacker sells the DVT into the Uniswap V1 exchange, increasing its DVT reserves and decreasing its ETH reserves. This causes the DVT/ETH spot price to collapse.
3. **Exploit the manipulated price:** The lending pool uses this manipulated spot price when calculating the ETH collateral required to borrow DVT.
4. **Calculate the reduced collateral requirement:** The attacker calculates the reduced ETH collateral required to borrow the entire `100,000 DVT` held by the lending pool.
5. **Borrow the pool's entire balance:** The attacker deposits the required ETH and borrows the entire `100,000 DVT`.
6. **Recover the borrowed tokens:** The attacker sends the borrowed DVT to the recovery account.
7. **Complete the attack:** Since the price manipulation and borrowing happen within the same transaction, the lending pool immediately uses the manipulated spot price.

## Why the Victim Loses Funds

The lending pool determines borrowing requirements using a spot price that the borrower can directly manipulate by trading against the Uniswap exchange.

The attacker makes their collateral appear more valuable relative to the DVT being borrowed, allowing them to borrow the entire `100,000 DVT` pool with only their available ETH. Consequently, the pool lends its entire token balance against insufficient collateral.

## Remediation

The protocol should not use an instantaneous AMM spot price as the sole oracle for determining collateral requirements.

Instead, it should use a more manipulation-resistant oracle mechanism, such as a time-weighted average price (TWAP) or an independent price oracle. Additional safeguards, such as price-deviation checks and liquidity/depth considerations, should also be implemented.

## Key Lesson

A price that is correct according to an AMM's current reserves is not necessarily a trustworthy oracle price.

A protocol must consider whether an attacker can cheaply manipulate the price it relies on before making economically important decisions.