# Naive Receiver

## Vulnerability

2 parts first for receiver and second for pool

The pool permits an arbitrary caller to initiate a flash loan on behalf of a receiver, and the receiver has no authorization check preventing this. Because the fee is charged to the receiver, an attacker can repeatedly force the receiver to pay fees.

The protocol allowed somebody who has not deposited anything to withdraw from the pool an arbitrary amount and also in same logic be withrawer and the whom the withdrawn amount is sent to be different .

## Root Cause
the main security door which we broke was making use of how _msgSender() worked , it is supposed to return the account for which the withdrawal logic against their funds would run

we identified that it returned last 20 bytes of the calldata and made the calldata in a way that it held fnselector byte for the dispatcher and then deployers  address, which allowed us to withdraw on it's behalf
## Broken Invariant / Assumption
One should only be able to withdraw the entitled amount

## Attack Path

1.call forwarder using attacker parameters
2.forwarder call withdraw which runs _msgSender
3.msgSender returns last 20 bytes of calldata which are deployers address
4.then withdraw logic sends all weth deployer was entitled to our provided recepient address

## Why the Victim Loses Funds
victim lost funds due to first allowing anybody to call withdraw
2) withdrawer and recepient amount could be different 
3) complicating msg.sender inspite of directly using msg.sender and just perform routine constraint checks 
## Remediation
now i will give remediation for both recepient and pool 
only some selected initiators whould be able to run onFlashLoan and not everybody otherwise somebody can force it to pay fee for something recepient didnot wanted to do
## Key Lesson

key lesson here is something may work well as individual functions but together behaviour may lead to invalid transitions 