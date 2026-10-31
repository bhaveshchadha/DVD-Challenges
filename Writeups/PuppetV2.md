# Puppet V2

## Vulnerability

The lending pool uses the current Uniswap V2 spot price, derived from the pair's reserves, to calculate the amount of WETH required as collateral for borrowing DVT.

Since the spot price is derived directly from the Uniswap pair's token and WETH reserves, an attacker can manipulate it by trading against the exchange. This allows the attacker to artificially reduce the DVT price used by the lending pool, consequently reducing the WETH collateral required to borrow DVT.

## Root Cause

The lending pool trusts a manipulable AMM spot price when calculating collateral requirements.

It uses the current Uniswap V2 reserve ratio without accounting for the possibility that an attacker can manipulate those reserves immediately before borrowing.

## Broken Invariant / Assumption

**Invariant**

The lending pool should not allow an attacker to manipulate the oracle price cheaply enough to obtain borrowing power that is not economically justified by their collateral.

**Violation**

The lending pool assumes that the Uniswap V2 spot price accurately represents the economic value of DVT and cannot be cheaply manipulated. However, an attacker can alter the pair's reserves through a large trade, manipulating the price used to calculate collateral requirements.

## Attack Path

1. **Prepare initial funds:** The attacker starts with `10,000 DVT` and `20 ETH`.
2. **Wrap ETH into WETH:** The attacker converts their `20 ETH` into WETH using `weth.deposit()`.
3. **Manipulate the Uniswap price:** The attacker sells all `10,000 DVT` into the Uniswap V2 pair in exchange for WETH. This significantly increases the DVT reserve and decreases the WETH reserve, causing the DVT/WETH spot price to collapse.
4. **Calculate the reduced collateral requirement:** The attacker calls `calculateDepositOfWETHRequired()` to determine the reduced WETH collateral required to borrow the lending pool's entire `1,000,000 DVT` balance.
5. **Combine available WETH:** The attacker now has the original `20 WETH` obtained by wrapping ETH, along with the WETH received from the Uniswap swap.
6. **Approve and deposit collateral:** The attacker approves the lending pool to transfer the required WETH and calls `borrow()` to borrow the entire `1,000,000 DVT`.
7. **Recover the borrowed tokens:** The attacker transfers the borrowed DVT to the recovery account.

## Why the Victim Loses Funds

The lending pool calculates collateral requirements using a spot price that the borrower can directly manipulate by trading against the Uniswap V2 pair.

By selling a large amount of DVT into the pair, the attacker artificially reduces its WETH-denominated spot price. The lending pool consequently calculates a much lower collateral requirement, allowing the attacker to borrow its entire `1,000,000 DVT` balance using the WETH available to them.

The pool therefore lends its entire token balance against insufficient collateral, resulting in an undercollateralized loan.

## Remediation

The protocol should not use an instantaneous AMM spot price as the sole oracle for determining collateral requirements.

Instead, it should use a more manipulation-resistant oracle mechanism, such as a time-weighted average price (TWAP) or an independent price oracle. Additional safeguards, such as price-deviation checks and liquidity/depth considerations, should also be implemented.

## Key Lesson

A price that is correct according to an AMM's current reserves is not necessarily a trustworthy oracle price.

A protocol must consider whether an attacker can cheaply manipulate the price it relies on before making economically important decisions.