# Wallet Mining

## Vulnerability

The challenge combines a storage collision in an upgradeable Authorizer with deterministic CREATE2 deployment.

The Authorizer is deployed behind a proxy. Due to an incorrect storage layout between the proxy and its implementation, the proxy's `upgrader` address overlaps with the implementation's `needsInit` variable.

This allows the attacker to call the Authorizer's initialization function again and modify its authorization rules.

Additionally, the Safe wallet uses CREATE2 deployment, making it possible to predict the address of a wallet before deployment. By calculating the correct nonce, the attacker can deploy a Safe at the predetermined deposit address containing 20 million DVT.

## Root Cause

There are two main issues:

**1. Storage collision in the Authorizer**

The `TransparentProxy` and `AuthorizerUpgradeable` use conflicting storage layouts.

The proxy stores its `upgrader` address in a storage slot that overlaps with the implementation's `needsInit` variable.

Because the proxy's storage contains the nonzero upgrader address, the initialization guard can be bypassed, allowing `authorizer.init()` to be called again through the proxy.

**2. Trust in deterministic wallet deployment**

The `WalletDeployer` relies on the Authorizer to determine whether a caller can deploy a Safe at a particular address.

However, the authorization rules can be modified through the initialization vulnerability.

Furthermore, Safe's CREATE2 deployment allows its address to be calculated in advance using the factory address, singleton, initializer and salt nonce.

## Broken Invariant / Assumption

- The Authorizer assumes its initialization can only happen once.
- The WalletDeployer assumes its Authorizer provides reliable deployment authorization.
- The deployment mechanism assumes that the requested wallet address corresponds to a valid deployment configuration.

The storage collision breaks the initialization assumption, allowing the attacker to change who is authorized to deploy at the deposit address.

## Attack Path

1. **Deploy an attacker contract**

   Deploy a helper contract that interacts with the Authorizer, WalletDeployer and Safe factory.

   This helper contract will become the caller of `WalletDeployer.drop()` and receive the deployment reward.

2. **Calculate the CREATE2 nonce**

   Safe's `createProxyWithNonce()` derives its salt using:

   ```solidity
   keccak256(
       abi.encodePacked(
           keccak256(initializer),
           saltNonce
       )
   )
   ```

   The resulting proxy address is calculated using the CREATE2 formula:

   \[
   A = \operatorname{last20bytes}
   \left(
   keccak256(0xff \Vert factory \Vert salt \Vert initCodeHash)
   \right)
   \]

   Since the Safe factory, singleton, proxy creation code and initializer are known, the resulting address can be predicted.

   Construct the Safe initializer with:
   - Owner: `user`
   - Threshold: `1`
   - Setup target: zero address
   - Setup data: empty

   Iterate through candidate salt nonces until the predicted Safe address matches `USER_DEPOSIT_ADDRESS`.

   The matching nonce is **13**.

3. **Reinitialize the Authorizer**

   The storage collision between `TransparentProxy.upgrader` and `AuthorizerUpgradeable.needsInit` allows the initialization function to be called again.

   Call:

   ```solidity
   authorizer.init(wards, aims);
   ```

   Configure the attacker's helper contract as the authorized deployer for `USER_DEPOSIT_ADDRESS`.

   The attacker can now pass the authorization check performed by `WalletDeployer.drop()`.

4. **Deploy the Safe at the deposit address**

   Call:

   ```solidity
   walletDeployer.drop(
       USER_DEPOSIT_ADDRESS,
       initializer,
       13
   );
   ```

   Since the helper contract is now authorized, the deployment proceeds.

   The Safe factory uses CREATE2 to deploy the proxy at the exact predetermined deposit address.

   The Safe is initialized with `user` as its sole owner and a threshold of one.

   The original 20 million DVT remains at the same address, but that address is now a deployed Safe proxy.

5. **Recover the 20 million DVT**

   The attacker constructs a Safe transaction that calls:

   ```solidity
   token.transfer(user, DEPOSIT_TOKEN_AMOUNT);
   ```

   Calculate the Safe transaction hash and sign it using `userPrivateKey`.

   Submit the signature through:

   ```solidity
   safe.execTransaction(...);
   ```

   The Safe verifies the owner's signature and executes the token transfer.

   This does not require the user to send an Ethereum transaction. The user authorizes the Safe transaction through a signature, so the user's EOA nonce remains zero.

6. **Transfer the deployment reward to ward**

   After successful deployment, `WalletDeployer.drop()` transfers its 1 DVT reward to the caller, which is the attacker's helper contract.

   Transfer this reward to `ward` to satisfy the challenge's final condition.

## Why the Victim Loses Funds

The attacker exploits the Authorizer's storage collision to modify deployment permissions.

This allows the attacker to deploy a Safe at the predetermined deposit address, even though the attacker was not originally authorized.

Because the deposit address already holds 20 million DVT, deploying the Safe there gives control over those tokens to the Safe's configured owner.

The attacker uses the user's available signing key to authorize a Safe transaction that transfers the entire balance to the user's account.

## Remediation

- Use unstructured or namespaced storage for proxy-specific variables to prevent storage collisions.
- Ensure proxy and implementation storage layouts are compatible.
- Implement initialization guards that cannot be bypassed through proxy storage.
- Use a proper one-time initializer mechanism and prevent unauthorized reinitialization.
- Ensure deployment authorization cannot be modified by an untrusted caller.
- Validate the complete deployment configuration, including initializer parameters, before allowing a deployment.

## Key Lesson

CREATE2 address prediction is not inherently a vulnerability. It is a deterministic deployment mechanism that allows addresses to be calculated before deployment.

The actual vulnerability comes from combining predictable deployment with broken authorization and initialization controls.

A secure proxy must preserve storage-layout compatibility, and an initialization function must remain protected even when executed through a proxy.