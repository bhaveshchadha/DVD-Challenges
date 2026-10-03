# Compromised

## Vulnerability
The private keys of 2 of the 3 trusted sources is compromised

## Root Cause
The web service accidentally exposes the private keys of two trusted oracle sources, allowing an attacker to impersonate those sources and call postPrice().
## Broken Invariant / Assumption
Only Trusted sources can change prices and they the sources are completely secure
It assumes having an Median saves against dangerous changes 
## Attack Path

1. from the response decode the private keys
2. then using these private keys sign and run the postprice fn on oracle
3. set 2 source prices to be 0 which makes the median price as 0
4. now buy at 0
5. again change the prices back to the maximum balance address has
6. now sell at these maximum prices thus draining the exchange completly
## Why the Victim Loses Funds
because it trusts only one oracle instead of depending on many, the oracle itself depends on too few sources , there are no mitigiation for preventing large price jumps  
## Remediation
Protect oracle reporter keys and use sufficiently independent data sources so that compromising a small number of reporters cannot control the aggregate price. Add sanity/deviation checks and circuit breakers for extreme price movements to limit the impact of oracle compromise. infact use multiple oracle systems 
## Key Lesson
never depend on single oracle or an oracle with too few sources or compromises pvt key system 