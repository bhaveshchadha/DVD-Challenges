# Truster

## Vulnerability

Lending Pool, allows caller to execute any arbitrary calldata against a caller supplied target contract, without restricting the permited operation, or validating that the requested operation is consistent with the intended lending process.

This allows an attacker to invoke the token's `approve()` through the pool, granting an arbitrary spender permission to transfer token from the pool's balance.

## Root Cause

The pool's `flashLoan()` function, allows caller to execute `target.functionCall(data)` operation, where caller supplied target can be any arbitrary contract address, executing caller supplied calldata for pool's context. 

## Broken Invariant / Assumption

**Invariant: **

Any callback or function executed inside pool's `flashLoan()` should be from a trusted source, should follow intended lending process .

**Violation**

Pool calls an arbitrary target contract, with arbitrary calldata, for pool's context . This allows attacker to approve pool's token balance to be spent by an attacker controlled address . 

## Attack Path

1. **Create an Malicious Receiver Contract**. This receiver address is approved to spend pool's balance, has a function that when triggered sends pool's balance to recovery address
2. **Craft an malicious calldata** The attacker uses `abi.encodeCall()` to encode a call to `approve()` pool's balance to be spent by `address(exploiter)`
3. **Trigger Flashloan** The attacker triggers `flashLoan` to execute `target.functionCall(data)` in pool, target is pool's selected token, calldata is our  crafted raw data .
4. **Use Exploiter Contract to recover Funds** Execute exploiter's `recoverFunds` to send pool's complete balance to recovery

## Why the Victim Loses Funds

Lender pool calls arbitrary calldata on arbitrary contract. Attacker use this to create an approval for an attacker controlled address to spend pools' complete balance. Then using the attacker controlled address all funds are sent to recovery address .

## Remediation

The pool should authenticate any contract that is called by it , validate that operation that follow intended lending process, not perform invalidate state transitions .

## Key Lesson

The pool should remove or strictly restrict caller-controlled external calls from flashLoan(). If external calls are required, any operation being performed, while pool's execution is not over, should be from trusted source, perform only valid state transitions .