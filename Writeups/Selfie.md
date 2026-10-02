# Selfie

## Vulnerability

The main vulnerability is that the governance system allows an attacker to use **temporary voting power obtained through a flash loan to satisfy the proposal threshold**, while not requiring that voting power to still exist when the governance action is executed after the delay.

## Root Cause

The governance action's eligibility is established when the action is **proposed/queued**, but the required voting power is **not revalidated when the action is executed**.

This allows the attacker to:

* obtain voting power temporarily,
* queue the malicious action,
* return the flash-loaned tokens,
* wait for the governance delay,
* and execute the action without still holding the tokens that gave them voting power.

## Broken Invariant / Assumption

The broken assumption is:

> **Once an action has satisfied the governance requirements, its authorization is assumed to remain valid until execution, even though the voting power used to authorize it can disappear.**

The governance system therefore treats proposal-time voting power as sufficient authorization for a later privileged state transition.

## Attack Path

1. Deploy a malicious attacker contract.
2. Take a flash loan of the governance tokens.
3. Delegate the borrowed tokens to obtain the required voting power.
4. Propose/queue a malicious governance action, such as `emergencyExit`.
5. The governance system accepts the action and starts the execution delay.
6. Return the flash-loaned tokens.
7. Wait until the governance delay has passed.
8. Execute the previously approved action without needing to still possess the voting power.
9. The malicious action transfers the pool's funds to the attacker's recovery address.

## Why the Victim Loses Funds

The attacker can use **temporary voting power to authorize a privileged action**, and the governance system does not recheck the required voting-power condition when that action is executed.

Therefore, the attacker can execute the malicious action even after the flash-loaned voting tokens have been returned.

## Remediation

Security-critical governance conditions should be validated at the appropriate stage of the state transition rather than assuming that conditions checked earlier remain valid indefinitely.

In particular, the governance design should prevent **temporary voting power from creating authorization that remains valid after that voting power disappears**.

## Key Lesson

> **A security-critical condition being valid at one stage of a state transition does not guarantee that it remains valid at a later stage.**

Governance systems must consider the entire lifecycle:

**propose → queue → delay → execute**

and ensure that assumptions made at one stage cannot be invalidated before the privileged action is executed.
