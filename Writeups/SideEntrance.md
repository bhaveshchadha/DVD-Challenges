# Side Entrance

## Vulnerability

The pool's flashLoan() function validates loan repayment by comparing its ETH balance before and after executing the borrower's receiver callback. However, during the callback, a malicious receiver can deposit the borrowed ETH back into the pool, creating a corresponding withdrawal entitlement without actually repaying the loan through the intended repayment mechanism.

This allows the receiver to satisfy the pool's balance validation while retaining the ability to withdraw the deposited ETH. By subsequently withdrawing the pool's entire balance, the attacker can drain the pool's funds.

## Root Cause

The pool equates restoration of its ETH balance with successful flash-loan repayment, without accounting for withdrawal liabilities that can be created during the receiver callback.

## ## Broken Invariant / Assumption

**Invariant**

A flash loan must be repaid within the same transaction. If the borrower fails to repay the loan, the transaction must revert, ensuring that the pool cannot lose funds.

**Violation**

The attacker-controlled receiver deposits the borrowed ETH back into the pool during the flash-loan callback, creating a corresponding withdrawal entitlement. This satisfies the pool's balance-based repayment validation without restoring the pool's funds free of withdrawal liabilities. The attacker subsequently withdraws the entitled ETH and transfers it to the recovery address, draining the pool.
## Attack Path



1. **Deploy a malicious receiver:** Create an `Exploiter` contract that can initiate a flash loan and execute logic during the receiver callback.

2. **Borrow the pool's entire ETH balance:** The `Exploiter` requests a flash loan for the pool's full balance.

3. **Deposit the borrowed ETH during the callback:** Instead of repaying the loan through a dedicated repayment mechanism, the `Exploiter` calls `deposit()` with the borrowed ETH. This restores the pool's ETH balance while creating a corresponding withdrawal entitlement for the `Exploiter`.

4. **Pass the repayment validation:** After the callback returns, the pool compares its current ETH balance with the balance recorded before the loan. Since the deposit restored the balance, the validation passes, despite the withdrawal liability created during the callback.

5. **Withdraw and recover the funds:** The `Exploiter` calls `withdraw()` to redeem its withdrawal entitlement and transfers the withdrawn ETH to the designated recovery address, draining the pool.


## Remediation

In the pool, After a flash loan, the pool must retain its pre-loan assets free of any unauthorized or newly created withdrawal liabilities. Repayment accounting and deposit accounting should be designed so that restoring the pool's raw ETH balance is not, by itself, sufficient to establish successful repayment. Any repayment mechanism must preserve this property even when the receiver executes arbitrary logic during the callback.


## Key Lesson

Flash-loan repayment must be validated using accounting that reflects the protocol's actual obligations, not merely its raw asset balance. A balance check is insufficient when operations during the callback can create new withdrawal liabilities.