# Truster

## Vulnerability

The pool allows the caller to control an arbitrary target and calldata for an
external call executed by the pool itself. This allows an attacker to make the
pool execute privileged operations, such as granting an allowance over the
pool's tokens, which can then be used to drain the pool.

## Root Cause

The lender performs an attacker-controlled low-level call on the pool's behalf
without restricting the target or calldata.

## Broken Invariant / Assumption

The pool's tokens should only be spendable according to permissions authorized
by the pool itself.

The attacker should not be able to make the pool grant an allowance to an
attacker-controlled spender.

## Attack Path

1. Attacker calls the `Execute` contract.
2. `Execute` calls `flashLoan()` with:
   - `amount = 0`
   - `borrower = pool`
   - `target = token`
   - calldata encoding `approve(Execute, poolBalance)`
3. The pool executes `target.functionCall(data)`.
4. The token contract therefore sees the pool as `msg.sender` and records an
   allowance from the pool to `Execute`.
5. `Execute` uses `transferFrom()` to transfer the pool's tokens to the
   recovery address.

## Remediation

The lender should not expose an arbitrary target + arbitrary calldata call
that executes with the lender's authority.

If arbitrary external calls are genuinely required, the protocol should
strictly constrain the permitted targets, functions, arguments, and resulting
state transitions.

## Key Lesson

Never give an untrusted caller an arbitrary external-call primitive that
executes with the authority of a privileged contract.