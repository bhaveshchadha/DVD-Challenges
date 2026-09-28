# Side Entrance

## Vulnerability

The pool's `flashLoan()` only checks whether its **raw ETH balance** has been restored after the loan. During the flash loan, the attacker can deposit the borrowed ETH back into the pool, causing the pool to consider that ETH a legitimate deposit belonging to the attacker.

The same ETH therefore satisfies the flash-loan repayment check **and** creates a withdrawable balance for the attacker.

## Root Cause

The pool separates its internal accounting:

```solidity
balances[msg.sender]
```

from its actual ETH balance:

```solidity
address(this).balance
```

and `flashLoan()` only verifies the latter.

## Broken Invariant / Assumption

ETH used to repay a flash loan must not simultaneously create a withdrawable balance for the borrower.

The pool incorrectly assumes:

> If its ETH balance is restored, the flash loan has been properly repaid.

## Attack Path

1. Attacker takes a flash loan for the entire pool balance.
2. During `execute()`, the attacker deposits the borrowed ETH back into the pool.
3. The pool's ETH balance is restored, so the flash-loan repayment check passes.
4. The deposited ETH is recorded in `balances[attacker]`, allowing the attacker to withdraw it afterward.

## Why the Victim Loses Funds

The pool treats the attacker's deposit as a legitimate claim even though the ETH came directly from the pool's own flash loan.

After the flash loan completes, the attacker can withdraw the credited balance, causing the pool to lose its entire ETH balance.

## Remediation

The flash-loan repayment mechanism should not rely solely on the pool's raw ETH balance.

The protocol should ensure that ETH used to satisfy the flash-loan repayment cannot simultaneously be credited as a withdrawable deposit, or use separate accounting/repayment mechanisms that distinguish genuine repayments from deposits.

## Key Lesson

**Never assume that restoring a contract's raw asset balance means a flash loan has been legitimately repaid when the same assets can create internal accounting claims.**
