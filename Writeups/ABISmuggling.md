# ABI Smuggling

## Vulnerability
There’s a permissioned vault with 1 million DVT tokens deposited. The vault allows withdrawing funds periodically, as well as taking all funds out in case of emergencies.

Vault set some permissions which cannot be changed ,removed, reset, added to later.

The permitted addresses run the permitted operation which validates some constraints like the operation asked to perform is permitted , sent by the permitted user
through
 function getActionId(bytes4 selector, address executor, address target) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(selector, executor, target));
    }

    where selector is selected through
    uint256 calldataOffset = 4 + 32 * 3; // calldata position where `actionData` begins
        assembly {
            selector := calldataload(calldataOffset)
        }

which puts the value at 100-131 bytes into the selector
but the operation is run with
    target.functionCall(actionData);

which runs the selector bytes offset provides

this discrepancy is what allows an attacker to run sweep funds to drain vault from all their tokens even tho they are not permitted to do that

## Root Cause

The value of selector for which permission is validated and the selector that is run can be different allowing an permitted address to perform at operation they were not permitted for which can used to drain all tokens from the vault

## Broken Invariant / Assumption
Self Authorized Vault assumes that execute fn inherited from Authorized executor only allows permitted accounts can run permitted operation but the discrepancy in how a selector value is derived and how function call runs an certain function allows an permitted address to run an operation they are not allowed to do 
## Attack Path

1. Player address is permitted to run withdraw fn on Self Authorized Vault 
2. Player directly performs an low level call on vault address using (bool success, ) = address(vault).call(rawCallData);
3. They construct an rawdata which put the 
4.

## Why the Victim Loses Funds

## Remediation

## Key Lesson