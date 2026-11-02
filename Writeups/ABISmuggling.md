# ABI Smuggling

## Vulnerability

The `SelfAuthorizedVault` contains an ABI smuggling vulnerability in its `execute()` function.

The function extracts the selector used for authorization from a fixed calldata offset instead of deriving it from the actual `actionData` payload.

However, the low-level call uses the ABI-decoded dynamic offset to locate `actionData`.

By crafting calldata with two different selectors at these locations, an attacker can pass authorization for an allowed function while executing a different, privileged function.

## Root Cause

The root cause is the inconsistency between how the vault performs authorization and how it executes the supplied calldata.

The authorization logic reads the selector from a fixed position in the outer calldata.

The actual low-level call, however, uses the dynamic offset specified in the ABI encoding of `execute(address,bytes)` to locate the inner calldata.

This allows the attacker to make the authorization check and the actual execution operate on different function selectors.

## Broken Invariant / Assumption

The function selector used for authorization must always be the same selector as the function selector of the calldata actually executed.

The vault assumes that the selector found at its fixed calldata offset represents the operation being executed, but an attacker can manipulate the dynamic ABI offset to violate this assumption.

## Attack Path

1. **Construct the privileged calldata**

   Encode a call to `sweepFunds(recovery, token)` using `abi.encodeCall()`.

   This produces the actual calldata that will transfer the vault's entire token balance to the recovery address.

2. **Craft the outer calldata**

   Manually construct the calldata for `execute(address,bytes)` instead of using normal ABI encoding.

   The crafted calldata contains:
   - The `execute(address,bytes)` selector.
   - The vault address as the target.
   - A dynamic offset of `0x80`, pointing to the location of the inner calldata's length field.
   - Padding and a permitted `withdraw` selector at the fixed offset used by the authorization logic.
   - The length of the actual `sweepFunds` calldata.
   - The actual `sweepFunds` calldata as the dynamic payload.

3. **Bypass authorization**

   The vault extracts the selector at its fixed calldata offset.

   Because the attacker placed the permitted `withdraw` selector at that location, the authorization check uses the player's valid permission for `withdraw`.

4. **Execute the privileged function**

   The ABI decoder follows the dynamic offset supplied in the outer calldata and extracts the actual `sweepFunds` payload.

   The vault then performs the low-level call using that payload.

   Consequently, `sweepFunds()` executes even though the authorization check validated `withdraw()`.

5. **Recover the tokens**

   The `sweepFunds()` call transfers the entire token balance from the vault to the recovery address, satisfying the challenge conditions.

## Why the Victim Loses Funds

The vault authorizes one operation but executes another.

The attacker uses a permitted function selector to pass the authorization check while supplying the calldata for the privileged `sweepFunds()` function.

This allows the attacker to drain all tokens held by the vault without having permission to call `sweepFunds()` directly.

## Remediation

- Extract the function selector from the actual decoded `actionData` rather than using a hardcoded offset in the outer calldata.
- Perform authorization against the exact calldata that will be executed.
- Avoid manually parsing ABI-encoded calldata when Solidity's ABI decoder can safely decode the arguments.
- Ensure that authorization and execution use the same validated operation and cannot interpret the calldata differently.

## Key Lesson

Never authorize a function using calldata that is parsed differently from the calldata that will actually be executed.

ABI dynamic offsets determine where dynamic arguments are located. If authorization relies on a fixed calldata position while execution follows the ABI offset, an attacker can make the two mechanisms interpret different operations.