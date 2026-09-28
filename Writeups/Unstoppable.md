# Unstoppable

## Vulnerability
main vulnerability lies in  if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance();totalsupply returns tdvt(shares), here it is converting shares into shares and comparing with assets instead of shares into assets hence wrong accounting check leads to an error and hence haults the protocol
## Root Cause
 if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance(); is the root cause
## Broken Invariant / Assumption

The vault assumes that its total share supply (tDVT) and its underlying DVT balance maintain a consistent asset-to-share relationship.

The intended invariant is:

convertToAssets(totalSupply) == balanceBefore

assumption was that flashloan will always check that the relation between tdvt and dvt is in valid state but it uses wrong formula
and checks for (convertToShares(totalSupply) != balanceBefore)
## Attack Path

1.from player transfer 10 dvt
2.will change shareprice from 1
3.due to faulty accounting method wrong calculation will happen and flashloan will fail
4.and in monitor the catch {
            // Something bad happened
            emit FlashLoanStatus(false);

            // Pause the vault
            vault.setPause(true);

            // Transfer ownership to allow review & fixes
            vault.transferOwnership(owner);
        } will run



## Remediation
use convertToAssets instead of convertToShares
## Key Lesson

a condition may pass for one value but fail for others

A check that passes under an initial 1:1 exchange rate does not necessarily remain valid when the underlying asset/share ratio changes. Always verify the units and assumptions behind accounting invariants.