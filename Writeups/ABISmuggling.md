# ABI Smuggling

There’s a permissioned vault with 1 million DVT tokens deposited. The vault allows withdrawing funds periodically, as well as taking all funds out in case of emergencies.

The contract has an embedded generic authorization scheme, only allowing known accounts to execute specific actions.

## Vulnerability
Execute function does authorization check using an selector read from a fixed calldata offset but executes  dynamically encoded calldata containing a different selector. Attacker exploits this mismatch to bypass the permission check and execute an operation for which they lack permission.


## Root Cause
Root cause is inconsistent calldata parsing between authorization and execution. The authorized operation is read from hardcoded absolute calldata offset(0x64) bytes while the executed operation is dynamically derived from ABI offset enoding(starting at 0x80 relative to ABI argument block) . Because the two calldata reads are not done from the same calldata slice , attackers crafted data pass permission checks using selector of permitted operation withdraw while executing priveleged operation sweep funds

## Broken Invariant / Assumption
Invariant: The operation authorized by the permission check must be the same operation executed against the target, with the authorization bound to the relevant target and execution context.

Violation: execute validation authorization can differ from the selector in actual calldata, allowing execution of an operation which lacks permission

## Attack Path

1. Prepare the non permitted privelege call: Use abi.encodeCall(
            vault.sweepFunds,
            (recovery, IERC20(address(token)))
        ); to generate the valid calldata that transfers vault's entire token balance to recovery
2. Start craftin Raw data and construct the outer call: Begin the rawcalldata with 4 bytes of execute and padded vault address as target
3. Manipulate the dynamic offset: Set the dynamic offset data to 0x80 relative to the ABI argument block ,The decoder consequently reads the dynamic bytes length from absolute calldata offset 0x84 and the payload begins 0xa4 .
4. Satisfy the authorization check : Pad the next 32 bytes and then place the first 4 bytes of withdraws selector at bytes offset 100

 bytes32(0),            
bytes32(uint256(uint32(0xd9caed12)) << 224),
5. Place the priveleged operation bytes: Place the length and priveleged innercalldata bytes prepared in step 1 which will be later used by the decoder to execute the low level call triggered
6. Execute the mismatched malicious payload : perform an low level call on vault using the rawcalldata prepared 
(bool success, ) = address(vault).call(rawCallData);
7. Verify that Vault's complete token balance was drained and send to recovery account.

## Why the Victim Loses Funds

Attacker passes the authorization check using the permitted withdraw selector but causes the vault to execute sweepfunds through the dynamically decoded payload . Because the sweep funds transfers the vault's entire balance to recovery account , all specified 10,000,000e18 dvt tokens are transferred to recovery despite attacker lacking the permission to invoke the priveleged sweep operation

## Remediation
The calldata slice from which the authorization happens and the one which is used to perform an operation should be the same. Selector should be extracted from the actual action data passed to execute , same action data then should be used to perform the functioncall on target

## Key Lesson
Operation being authorized and operation being executed should always be the same  

