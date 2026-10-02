# Selfie

## Vulnerability
Here the main vulnerabiltiy was the fact that it treats time limit as a complete protection gainst fraudulent vote due to flash loan tokens but don't consider doing checks like checking balance of delegator while the actual execute happens
## Root Cause
can query an action using flash laons, execute it later without checking at the time of execution ,the eligibility
## Broken Invariant / Assumption
Assumption here is timelimit itslef is treated as complete protection against voting tokens botught using flash loan
## Attack Path

1.first create  maliciousloan attacker contract
2.on the attacker, call execute while also sending necessary arguments attacker would need,like governance token,recovery address
3.then lender call flashloan where action is queried
4.then in foundry test warp to 2 days and execute the action

## Why the Victim Loses Funds
because they fail to make proper constraints againt misuse of flashloans
## Remediation
while executing check for all the necessary constraints that are required for state transition to stay valid
## Key Lesson
constaints should be ser for each step individually even if only one thing changes