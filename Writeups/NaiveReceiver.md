# Naive Receiver 

## Vulnerability 

The challenge contains two security weaknesses that can be combined to recover all funds held by the flash-loan receiver and lending pool.

First, the lending pool allows any caller to initiate flash loans for an arbitrary receiver, while the receiver does not authenticate the loan's initiator. Because the pool charges a fixed fee of 1 WETH regardless of the amount borrowed, an attacker can repeatedly initiate zero-amount flash loans to drain the receiver's 10 WETH.

Second, the pool's multicall and trusted-forwarder integration allows crafted calldata to manipulate the effective sender used by the withdrawal logic. By appending a carefully chosen address to the encoded withdrawal calldata and executing it through the trusted forwarder, the attacker can bypass the intended depositor-accounting restriction and withdraw the pool's 1,000 WETH.

Together, these weaknesses allow an attacker to transfer all 1,010 WETH held by the receiver and pool to the designated recovery address.

## Root Cause

### 1. Unauthenticated Flash-Loan Initiation

The pool's `flashLoan()` function allows callers to select the receiver of a flash loan without requiring the receiver to authorize the initiator.

Although the receiver validates that the callback comes from its configured pool, it does not adequately validate the `initiator` argument in `onFlashLoan()`. Consequently, an attacker can trigger the receiver's callback indirectly through the trusted pool and cause it to pay the flash-loan fee without its consent.

The fee is fixed at 1 WETH, even when the borrowed amount is zero. This allows repeated zero-amount flash loans to consume the receiver's balance.

### 2. Sender-Context Confusion in Multicall

The pool uses a trusted forwarder to support meta-transactions and inherits multicall functionality that executes multiple calls using delegatecall.

The multicall implementation appends context derived from the original caller to the calldata of each subcall. The context-handling logic can interpret the trailing 20 bytes of calldata as the effective sender when the call originates from the trusted forwarder.

The attacker crafts the withdrawal calldata so that the appended address is interpreted as the deployer rather than the player. When the withdrawal function resolves the effective sender through `_msgSender()`, it uses the manipulated context to identify the deployer, whose deposit accounting permits withdrawal of the pool's funds.

The root cause is an unsafe interaction between the trusted-forwarder sender-resolution mechanism and multicall's handling of trailing calldata. The contract does not ensure that the effective sender used for authorization and accounting is derived from an unambiguous, trustworthy context.

## Broken Invariants / Assumptions

**Invariant 1 — Authorized Flash-Loan Initiation**

A receiver must not spend its funds to repay a flash loan unless the operation was initiated or explicitly authorized by a trusted party.

**Violation:** The receiver accepts callbacks from the trusted pool without validating the loan initiator. An attacker can therefore trigger fee payments from the receiver's WETH balance.

**Invariant 2 — Authentic Sender Context**

The effective sender used for authorization and balance accounting must faithfully represent the account that authorized the operation. User-controlled calldata must not allow an attacker to impersonate another account.

**Violation:** The interaction between multicall, the trusted forwarder, and sender-resolution logic allows the attacker to manipulate the effective sender used by the withdrawal function. This enables the attacker to withdraw funds using the deployer's deposit accounting.

## Attack Path

### Phase 1 — Drain the Flash-Loan Receiver

1. **Identify the fee-draining vulnerability.** The receiver holds 10 WETH, and the pool charges a fixed fee of 1 WETH per flash loan, even when the borrowed amount is zero.

2. **Initiate zero-amount flash loans.** The attacker repeatedly calls `pool.flashLoan(receiver, address(weth), 0, bytes(""))`, specifying the receiver as the borrower.

3. **Trigger the receiver's callback.** The pool invokes `onFlashLoan()` on the receiver. Because the receiver does not authenticate the initiator, it accepts the callback and repays the fixed fee.

4. **Repeat until the receiver is empty.** Ten successful zero-amount flash loans consume the receiver's entire 10 WETH balance.

### Phase 2 — Withdraw the Lending Pool's Funds

5. **Construct the withdrawal calldata.** The attacker uses `abi.encodeCall()` to encode a call to `pool.withdraw()`, requesting withdrawal of 1,010 WETH to the recovery address.

6. **Manipulate the sender context.** The attacker appends `bytes20(deployer)` to the encoded withdrawal calldata. This value is intended to be interpreted as the effective sender by the vulnerable sender-context mechanism.

7. **Wrap the withdrawal in multicall.** The crafted withdrawal calldata is placed inside a `bytes[]` array and encoded as a call to `pool.multicall()`. This routes execution through the multicall implementation, which uses delegatecall and interacts with the context-handling logic.

8. **Create and sign the forwarder request.** The attacker constructs a `BasicForwarder.Request` targeting the pool, including the multicall calldata, the current nonce, a gas limit, and a deadline. The attacker signs the request using the player's private key so the trusted forwarder accepts it.

9. **Execute the meta-transaction.** The attacker submits the signed request to `forwarder.execute()`. During nested execution, the manipulated trailing calldata influences sender resolution, causing the withdrawal logic to use the deployer's identity for deposit accounting.

10. **Transfer the pool's WETH to recovery.** The withdrawal succeeds against the deployer's recorded deposit, transferring the pool's 1,000 WETH to the recovery address. Combined with the 10 WETH previously drained from the receiver, the recovery address receives all 1,010 WETH.

## Impact

An attacker can drain the receiver's entire 10 WETH balance by initiating zero-amount flash loans that incur a fixed 1 WETH fee.

The sender-context vulnerability additionally allows the attacker to bypass the intended withdrawal-accounting restriction and withdraw the lending pool's 1,000 WETH.

In the challenge setup, the combined impact is the unauthorized transfer of **1,010 WETH** to the recovery address. The attack also demonstrates that the receiver's funds can be consumed without its consent and that the pool's depositor-accounting protections can be bypassed through manipulated sender context.

## Remediation

### 1. Authenticate Flash-Loan Initiators

The receiver should validate the `initiator` argument in `onFlashLoan()` against an explicit authorization policy before approving repayment or allowing its funds to be spent.

The receiver should continue verifying that `msg.sender` is its trusted lending pool. However, authenticating the pool alone is insufficient because any account may be able to invoke the pool and trigger a callback.

### 2. Make Sender Context Unambiguous

The trusted-forwarder and multicall implementations should use a sender-resolution mechanism that cannot be manipulated by appending arbitrary trailing bytes to user-controlled calldata.

Possible approaches include:

- Avoiding ad hoc extraction of the effective sender from the final 20 bytes of calldata.
- Ensuring that any sender context appended by multicall is derived from a trusted execution context and cannot be forged by the original caller.
- Using a consistent, well-reviewed meta-transaction implementation with clearly defined behavior for nested calls and delegatecall.
- Ensuring authorization and depositor accounting use the same authenticated sender identity throughout execution.

### 3. Preserve Authorization Across Nested Calls

Functions that modify balances or transfer assets should enforce authorization based on a trustworthy caller identity. Nested execution through multicall or a forwarder must not change that identity in a way that allows one account to spend another account's recorded balance.

## Key Lessons

1. **Authenticate the initiator, not just the callback caller.** A trusted pool can still be abused to trigger operations that a receiver never authorized.

2. **Zero-amount operations can still have financial consequences.** A fixed fee independent of the borrowed amount makes zero-amount flash loans a mechanism for draining funds.

3. **Meta-transactions and multicall introduce sender-context risks.** The interaction between delegatecall, appended calldata, trusted forwarders, and `_msgSender()` must be examined carefully.

4. **Authorization and accounting must use a trustworthy identity.** If an attacker can manipulate the identity used for balance accounting, depositor restrictions can become ineffective.

5. **Analyze combined exploit paths.** The receiver-draining vulnerability and sender-context vulnerability are distinct issues. Solving the complete challenge requires understanding both and how they contribute to the final recovery of funds.