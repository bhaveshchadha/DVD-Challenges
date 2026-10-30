# Selfie

## Vulnerability

The SelfiePool contract exposes an `emergencyExit()` function that transfers its entire token balance to a specified recipient. However, this function can only be called by the governance contract.

The SimpleGovernance contract exposes `queueAction()` and `executeAction()` functions, allowing anyone to queue and execute governance actions, provided the caller satisfies the voting-power requirement when queuing an action and the governance delay has elapsed before execution.

An attacker can exploit the pool's `flashLoan()` function to temporarily borrow the pool's entire token balance and delegate the borrowed token's voting power to a malicious receiver contract, which during the flashLoan execution, calls `governance.queueAction()`, queuing action `SelfiePool.emergencyExit()`, using borrowed voting power, this queued action is executed using `executeAction()`, after the execution delay has elapsed , calling `emergencyExit()` from the governance contract.

This allows the attacker to drain the pool without permanently holding the tokens used to satisfy the governance voting-power requirement.

## Root Cause
The governance contract validates voting power at proposal-queuing time but does not ensure that the voting power used to authorize the proposal represents a sufficiently durable commitment. Consequently, temporarily borrowed voting power can authorize an action that remains executable after the borrowed tokens have been returned.

## Broken Invariant / Assumption
Invariant: Governance actions must not be authorizable using voting power that can be temporarily acquired and returned immediately after proposal submission, while the resulting proposal remains executable. 

Violation: The attacker temporarily borrows the pool's tokens, delegates their voting power to the receiver, and queues a governance action. The flash loan is then repaid, but the queued action remains valid and can be executed after the governance delay .

## Attack Path

1. **Deploy a malicious receiver:** Create an `exploiter` contract that can initiate a flash loan and execute logic during the receiver callback
2. **Craft Raw Calldata** Create an ABI encoded invocation of `SelfiePool.emergencyExit(recovery)`, recovery being the designate recovery address, store it in `bytes memory data`.
3.**Trigger a flash loan with malicious arguments** Initiate a flash loan from the pool, specifying exploiter as the receiver, token as the loan asset, TOKENS_IN_POOL as the loan amount, and data as the callback data.
4.**Delegate Voting Power and Queue an action** Delegate all loaned token to the receiver as voting power , queue an action, which when executed will perform function call on pool,for data supplied as the callData.
5.**Repay and Execute the action after deadine** Approve lender to pull back the lent tokens with Fees. In the solidity foundry test contract, use ` vm.warp(block.timestamp + 2 days)` to allow the execution delay to elapse,  `governance.executeAction(1)` to execute the queued action.

## Why the Victim Loses Funds
Governance Contract from security perspective, wants to make sure that an action can be executed only using tokens caller actually owns, thus seperating the operation into,queuing an action, executing it only after a set time has passed, but in actual implementation, it doesn't check that when execution is triggered the account that queued the operation still holds the voting power needed, allowing an attacker to queue an operation which will send 1.5 million DVT to supplied recovery account using loaned tokens, execute this operation when timelimit is crossed.

## Remediation

Introduce proposal eligibility rules that require voting power to be held over a defined period. Like validating that the voting power used to authorize the proposal represents a sufficiently durable commitment

## Key Lesson

A timelock delays execution; it does not make the original authorization trustworthy. Governance systems must prevent temporarily acquired voting power from authorizing persistent actions.