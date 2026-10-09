# Climber

## Vulnerability
Owner of ClimberVault contract where our main vault (uups) implementation logic lies is owned by the ClimberTimelock contract , in the timelock cntract there are schedule and execute fn , anybody can call execute but assumption is only prescheduled fn would be executed otherwise a revert will happen, and only the account with proposer role can schedule actions. But in execute there lies a big vulnerability which is 


 bytes32 id = getOperationId(targets, values, dataElements, salt);

        for (uint8 i = 0; i < targets.length; ++i) {
            targets[i].functionCallWithValue(dataElements[i], values[i]);
        }

        if (getOperationState(id) != OperationState.ReadyForExecution) {
            revert NotReadyForExecution(id);
        }

the actions are performed before it is validated that the particular operation is scheduled or not 
allowing an attacker to execute an set of operation in an order which allows it to upgrade implementation of vault to a malicious one , reduce the delay to 0, grant exploiter proposer role, allowing to schedule the same batch of operations before the execution's readiness check are performed

## Root Cause
The timelock performs its scheduling/readiness validation after executing the batch's actions, instead of enforcing those preconditions before execution

## Broken Invariant / Assumption
Timelock assumes that only previously scheduled operations whose delay have elapsed can be executed, but allowing the batch to schedule itself and change itself before the validation , attacker violates the assumption and gain control over the vault's implementation .

## Attack Path

1. We create 2 malicious contracts MaliciousImplementation and ExploitTimelockExecute and create both of their instances
2. we construct execute exploiter instance by passing it the climbervault instance , timelock instance and address of malicious implementation's instance 
3. In the exploiter, We create 2 fn's executeAttack() and maliciousScheduling()
4. In global space of exploiter we declare the arguments we will need to schedule and execute an operation (targets, values, dataElements, salt)
5. in execute we create the target array(contains addresses),salt,values,dataelements(contains bytes of the fn selector and arguments we want to run) which are then passed as 
for (uint8 i = 0; i < targets.length; ++i) {
            targets[i].functionCallWithValue(dataElements[i], values[i]);
        }
in timelock execute 
6. our malicous execute path is to first run vault's upgradeToAndCall from timelock itself and upgrade the implemntation  to our malicious implementation     
7. then set delay to 0 so that operation becomes ready before it performs it's readiness checks
8. then we grant our exploiter proposer role so that it can schedule our operation so that it passes the validation checks in execute 
if (getOperationState(id) != OperationState.ReadyForExecution) {
            revert NotReadyForExecution(id);
        }

9.  then we run the malicious schedule fn which in turn runs 
        timelock.schedule(targets, values, dataElements, salt);
10. we execute the attack , use our malicious implementations to pull all it's dvt tokens and send them to recovery account 

## Why the Victim Loses Funds

The vault trusts it's timelock as it's owner . The attacks exploits the execution order flaw of the timelock to upgrade vault to a malicious implementation . The new implementation is then used to drain all dvt tokens of vault and sent to recovery account

## Remediation
Have the execute fn in Timelock contract to follow the cei pattern so that no arbitrary user can perform an action which is not already scheduled.

example:
function execute(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt)
        external
        payable
    {
        if (targets.length <= MIN_TARGETS) {
            revert InvalidTargetsCount();
        }

        if (targets.length != values.length) {
            revert InvalidValuesCount();
        }

        if (targets.length != dataElements.length) {
            revert InvalidDataElementsCount();
        }

        bytes32 id = getOperationId(targets, values, dataElements, salt);

        if (getOperationState(id) != OperationState.ReadyForExecution) {
            revert NotReadyForExecution(id);
        }
        operations[id].executed = true;
        
        for (uint8 i = 0; i < targets.length; ++i) {
            targets[i].functionCallWithValue(dataElements[i], values[i]);
        }

       

    }

## Key Lesson

Always Validate and execute preconditions necessary to make an external call . Never allow an operation to establish conditions which are supposed to validate that same operation