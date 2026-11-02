# Backdoor

## Vulnerability

The `WalletRegistry` contract distributes `10 DVT` to each beneficiary who successfully registers a Safe wallet. However, the registry does not adequately restrict the Safe wallet's initialization process.

The attacker can exploit `SafeProxyFactory.createProxyWithCallback()` to deploy wallets for the registered beneficiaries while supplying a malicious initializer.

During wallet initialization, the Safe's `setup()` function executes a caller-supplied delegatecall to the attacker's `Exploiter` contract. This allows the attacker to execute arbitrary logic in the context of the newly deployed Safe wallet.

The attacker uses this delegatecall to approve the player's address to spend `10 DVT` from the Safe wallet. Once the wallet is registered and the registry transfers the reward tokens to it, the attacker can use the allowance to transfer those tokens to the recovery account.

By repeating this process for all four beneficiaries, the attacker drains all `40 DVT` held by the registry.

## Root Cause

The root cause is the registry's reliance on externally supplied Safe wallet initialization without restricting the initialization parameters or validating the security of the resulting wallet configuration.

The Safe's `setup()` function accepts a caller-supplied target and calldata for an optional delegatecall. Since this delegatecall executes in the context of the Safe wallet, malicious initialization logic can modify the wallet's state and grant token-spending permissions to an attacker-controlled address.

The registry does not prevent this malicious initialization while registering beneficiary wallets.

## Broken Invariant / Assumption

**Invariant**

A beneficiary's newly registered Safe wallet must be initialized with a trusted configuration and must not grant unauthorized addresses permission to spend its assets.

**Violation**

The attacker supplies malicious initialization data that causes the Safe wallet to delegatecall an attacker-controlled contract. The malicious logic executes in the wallet's context and approves the player to spend the wallet's DVT tokens.

The registry subsequently transfers the reward tokens to the wallet, but the attacker already has the allowance required to transfer those tokens out.

## Attack Path

1. **Deploy a malicious helper contract:** Create an `Exploiter` contract containing an `exploit()` function that approves the player's address to spend `10 DVT` from the Safe wallet.

2. **Construct malicious initialization calldata:** Use `abi.encodeCall()` to encode a call to `Safe.setup()`. Configure the Safe with the corresponding beneficiary as its owner, a threshold of `1`, and the attacker's helper contract as the delegatecall target. Supply calldata encoding `Exploiter.exploit(token, player, AMOUNT_TOKENS_REWARDED)`.

3. **Deploy and initialize the Safe wallet:** Call `walletFactory.createProxyWithCallback()`, passing the Safe singleton, malicious initialization calldata, a unique salt nonce, and `walletRegistry` as the callback.

4. **Execute the malicious delegatecall:** During `Safe.setup()`, the Safe delegatecalls the attacker's helper contract. The `exploit()` function executes in the context of the Safe wallet, causing the token approval to be granted from the Safe wallet's address to the player.

5. **Register the beneficiary wallet:** The factory invokes the registry callback, which validates and registers the newly deployed Safe wallet and transfers the `10 DVT` reward to it.

6. **Recover the tokens:** The attacker calls `token.transferFrom(proxy, recovery, AMOUNT_TOKENS_REWARDED)`, using the allowance established during initialization to transfer the reward tokens to the recovery account.

7. **Repeat for all beneficiaries:** Repeat the process for all four registered beneficiaries, recovering the entire `40 DVT` held by the registry.

## Why the Victim Loses Funds

The registry transfers `10 DVT` to each beneficiary's newly registered Safe wallet, assuming that the wallet has been initialized securely.

However, the attacker exploits the initialization process to grant the player's address permission to spend tokens held by each Safe wallet.

Once the registry transfers the rewards, the attacker uses the previously established allowances to transfer all four rewards to the recovery account, draining the entire `40 DVT` distribution.

## Remediation

The registry should not blindly trust externally supplied wallet initialization parameters.

It should enforce a trusted and predictable Safe initialization process, validate the resulting wallet configuration, and prevent arbitrary delegatecall targets or calldata from being supplied during wallet creation.

In particular, wallet initialization should not allow untrusted callers to execute arbitrary logic in the context of a newly deployed wallet.

## Key Lesson

A delegatecall executes another contract's code using the calling contract's storage and address context.

Consequently, an initialization process that permits arbitrary delegatecalls can allow an attacker to modify a newly deployed wallet's state or grant unauthorized permissions before the wallet begins holding assets.

Wallet creation and initialization must therefore be treated as security-critical operations, not merely deployment steps.