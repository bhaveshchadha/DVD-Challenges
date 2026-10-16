# Unstoppable

## Vulnerability
The flashLoan function incorrectly passes totalSupply, which represents outstanding vault shares, to convertToshares() function, which expects an asset amount. The resulting share value is compared with vault's underlying asset balance . An Attacker donates directly to the vault, altering the asset-to-share conversion rate and and causing this flawed invariant check to fail, making subsequent flash loans revert.

## Root Cause
Root cause is an incorrect conversion function used in vault's accounting Invariant check.  
In the check, convertToShares(totalSupply) incorrectly converts totalSupply,which represents shares, then compares it with total underlying token balance, whch represent assets. 

## Broken Invariant / Assumption
Invariant: The vault's underlying asset balance must equal the asset value of it's outstanding shares, as determined by the vault's conversion rule . 

Violation: The invariant check applies convertToShares() to an existing Share quantity , treating shares as though they are tokens. It then compares this incorrect converted shares with vault's total underlying asset balance. A direct token donation changes assets-to-share conversion rate, causing this incorrect check to supsequently fail, blocking flash loan operation.

## Attack Path

Player transfers tokens to the vault

        token.transfer(address(vault), INITIAL_PLAYER_TOKEN_BALANCE);



## Impact
Attack causes the Vault's underlying token balance to increase while outstanding shares quantity remains the same, this attack consequently changes the asset-to-share conversion rate .

Now underlying assets != outstanding shares, which means assets-to-share conversion rate is no longer 1. 

Before the attack :
if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance(); 
didn't revert, because totalSupply was equal to balanceBefore, and convertToShares(totalSupply) used conversion rate 1.


Now after the attack, when Flash Loan is triggered and we reach the invariant check subsequently, blocking flashLoan functionality, creating a denial-of-service situation.


## Remediation

The bug can simply be removed by replacing the incorrect convertToShares()conversion function with the correct convertToAssets() function, So that the invariant check then confirms that the vault's underlying asset balance must be equal to the asset value of it's outstanding shares.

## Key Lesson

Accounting invariants checks must respect the meaning and units of the quantities being compared. In tokenized vaults, assets and shares are different quantities related by a conversion rate; using the wrong conversion direction can turn an intended safety check into a denial-of-service vulnerability.