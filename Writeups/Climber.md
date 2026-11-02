# Climber

## Vulnerability

The ClimberTimelock allows an operation to execute its actions before validating whether the operation has been scheduled and is ready for execution.

This allows an attacker to modify the timelock's configuration during execution, schedule the very operation currently being executed, and satisfy the final readiness check within the same transaction.

By combining this with an unrestricted UUPS implementation upgrade, the attacker can take control of the vault and drain its tokens.

## Root Cause

The root cause is the incorrect execution order in `ClimberTimelock.execute()`.

The timelock executes the supplied targets and calldata before performing its final check that the operation is scheduled and ready.

This creates an opportunity to manipulate the timelock's state during execution.

The vault also uses a UUPS proxy, allowing its implementation to be upgraded by its owner. Since the timelock is the vault's owner, an attacker can use the timelock's own execution mechanism to authorize an upgrade.

## Broken Invariant / Assumption

An operation must be scheduled and satisfy the timelock delay before any of its actions can execute.

The timelock assumes that an operation's readiness is established before execution, but its implementation validates this condition too late.

## Attack Path

1. **Deploy a malicious implementation**

   Deploy `MaliciousImplementation`, which inherits `UUPSUpgradeable` and implements `_authorizeUpgrade()`.

   It also introduces a `sweepFunds()` function that transfers the proxy's entire token balance to the caller.

2. **Prepare the execution batch**

   Deploy `ExploitTimelockExecute` and construct a batch containing four actions:

   - Upgrade the vault's implementation to `MaliciousImplementation`.
   - Set the timelock delay to zero using `updateDelay(0)`.
   - Grant the helper contract `PROPOSER_ROLE`.
   - Call `maliciousScheduling()` on the helper contract.

3. **Execute the batch**

   Call `timelock.execute()` with the four actions.

   The timelock executes them before its final operation-readiness check.

   - The first action upgrades the vault's implementation. The call originates from the timelock, which is the vault's owner.
   - The second action changes the timelock delay to zero.
   - The third action grants the helper contract proposer privileges.
   - The fourth action calls `maliciousScheduling()`, which invokes `timelock.schedule()` with the same targets, values, calldata, and salt as the currently executing operation.

4. **Pass the final readiness check**

   The operation is now scheduled, and its delay is zero. Its scheduled ready time is therefore the current block timestamp.

   When `execute()` performs its final readiness check, the operation is already considered ready, allowing the execution to complete.

5. **Drain the vault**

   The vault now uses the malicious implementation.

   Call `vault.sweepFunds(address(token))`. Because the function executes through the proxy, `address(this)` refers to the vault proxy, and the entire token balance is transferred to the caller.

   Finally, transfer the tokens to the recovery address.

## Why the Victim Loses Funds

The timelock's execution order allows an attacker to bypass the intended scheduling and delay requirements.

The attacker uses this to upgrade the vault implementation without waiting for the configured one-hour delay.

Once the malicious implementation is active, the attacker can transfer all tokens held by the vault proxy.

## Remediation

- Validate that an operation is scheduled and ready **before** executing any of its actions.
- Do not allow an operation to schedule itself during its own execution.
- Restrict changes to critical timelock configuration, particularly the execution delay.
- Ensure that proposer-role administration and timelock governance cannot be manipulated through an unvalidated execution batch.

## Key Lesson

A timelock is only as secure as the order in which it validates and executes operations.

Checking authorization or operation readiness after executing user-supplied actions is too late. An attacker may manipulate the very state used by the final validation check.