# The Rewarder

## Vulnerability

The `TheRewarderDistributor` contract allows beneficiaries to claim their allocated DVT and WETH rewards by submitting Merkle proofs through `claimRewards()`.

However, the contract does not immediately update the claimed status of a beneficiary's reward when processing each individual claim. Instead, it defers updating the claimed status until it finishes processing claims for the current token.

This allows an attacker to submit multiple identical claims for the same beneficiary, token, and distribution batch within a single `claimRewards()` transaction.

Since the claimed status has not yet been updated, the distributor accepts each repeated claim as valid and processes the same reward multiple times.

By exploiting this behavior with valid Merkle proofs for both DVT and WETH, the attacker can drain almost all the remaining tokens from the distributor.

## Root Cause

The root cause is the delayed updating of the claimed bitmap in `claimRewards()`.

The distributor processes multiple claims for the same token before recording that the beneficiary has already claimed the corresponding distribution batch.

Consequently, repeated claims within the same transaction are not recognized as duplicates, allowing the same Merkle-verified reward to be processed multiple times.

## Broken Invariant / Assumption

**Invariant**

A beneficiary must be able to claim a particular reward from a distribution batch only once, regardless of how many claims are submitted within a single transaction.

**Violation**

The attacker submits multiple identical claims using the same valid Merkle proof. Since the distributor delays updating the claimed bitmap until it finishes processing claims for the current token, each repeated claim is accepted.

The attacker can therefore receive the same allocated reward multiple times within a single transaction, even though the reward should only be claimable once.

## Attack Path

1. **Obtain valid Merkle proofs:** Load the DVT and WETH distribution files and generate the player's Merkle proofs using Murky. The player's address is located at index `188` in both distribution files.

2. **Construct repeated DVT claims:** Create a valid DVT claim using batch number `0`, the player's allocated DVT amount, and the corresponding Merkle proof. Repeat this identical claim multiple times.

3. **Construct repeated WETH claims:** Create a valid WETH claim using batch number `0`, the player's allocated WETH amount, and its corresponding Merkle proof. Repeat this claim multiple times as well.

4. **Calculate the number of claims:** Read the distributor's remaining DVT and WETH balances using `getRemaining()`. Divide each remaining balance by the corresponding player reward amount to determine the maximum number of repeated claims that can be processed without exceeding the available distribution balance.

5. **Group claims by token:** Construct a single `Claim[]` array containing all repeated DVT claims first, followed by all repeated WETH claims. Supply both token addresses in the `inputTokens` array, with DVT at index `0` and WETH at index `1`.

6. **Execute the repeated claims:** Call `distributor.claimRewards()` once with the constructed arrays. The distributor processes the repeated DVT claims before updating their claimed status when it moves to WETH. It then processes the repeated WETH claims before recording their claimed status at the end of processing.

7. **Recover the tokens:** After receiving the repeated claim rewards, transfer the player's entire DVT and WETH balances to the designated recovery account.

## Why the Victim Loses Funds

The distributor relies on the claimed bitmap to prevent beneficiaries from claiming the same distribution more than once. However, because the claimed status is updated only after processing the claims for a particular token, the same reward can be processed repeatedly within a single transaction.

The attacker exploits this accounting flaw by submitting hundreds of identical claims for both DVT and WETH, using valid Merkle proofs.

This allows the attacker to claim almost all the remaining DVT and WETH held by the distributor, leaving only small amounts of dust due to integer division when calculating the maximum number of claims.

## Remediation

The distributor should update the claimed status immediately when processing each claim, before proceeding with subsequent claims.

It should also prevent duplicate claims for the same beneficiary, token, and distribution batch within a single transaction.

The claimed bitmap should be updated before transferring tokens or processing additional claims, ensuring that repeated claims cannot be accepted before the claimed status is recorded.

## Key Lesson

A valid Merkle proof establishes that a beneficiary is entitled to a particular reward, but it does not guarantee that the reward has not already been claimed.

Claim verification and replay protection must be enforced together. Security checks that are deferred until the end of a batch or transaction can allow the same authorization to be reused multiple times within that execution.