# Compromised

## Vulnerability

The `TrustfulOracle` contract determines asset prices using the median of prices submitted by a set of trusted sources. However, the private keys of two trusted sources have been compromised, allowing an attacker to submit price updates on their behalf.

Since the oracle uses the median of the submitted prices, compromising two out of its three trusted sources gives the attacker sufficient control to manipulate the reported price.

An attacker can exploit this to temporarily reduce the DVNFT price to zero, purchase an NFT at a negligible cost, restore the oracle price to its original value, and sell the NFT back to the exchange at the original price.

This allows the attacker to drain the exchange's ETH balance while leaving the oracle's final reported price unchanged.

## Root Cause

The oracle relies on trusted source addresses to submit price updates, but the security of these sources depends on the confidentiality of their private keys.

Once two source private keys are compromised, an attacker can submit authorized price updates on behalf of those sources and manipulate the median price returned by the oracle.

The exchange subsequently trusts this manipulated oracle price when determining NFT purchase and selling prices.

## Broken Invariant / Assumption

**Invariant**

The oracle must provide a trustworthy and manipulation-resistant price that accurately represents the underlying asset's value. The exchange must not execute trades based on prices that an attacker can manipulate by compromising a small portion of the oracle's trusted sources.

**Violation**

The attacker obtains control of two trusted source accounts and submits a price of zero from both.

With three sources reporting prices of `0`, `0`, and `999 ether`, the median price becomes zero. The attacker purchases an NFT at this manipulated price.

The attacker subsequently restores both compromised sources' reported prices to `999 ether`, restoring the median price before selling the NFT back to the exchange.

## Attack Path

1. **Obtain compromised source credentials:** Use the leaked private keys of two trusted oracle sources to gain the ability to submit authorized price updates on their behalf.

2. **Manipulate the oracle price:** Submit a price of zero from both compromised sources using `postPrice("DVNFT", 0)`. With the three reported prices now being `0`, `0`, and `999 ether`, the median price becomes zero.

3. **Purchase an NFT at the manipulated price:** Call `exchange.buyOne()` with the player's available `0.1 ETH`. Since the oracle reports a zero price, the attacker can purchase an NFT for effectively nothing.

4. **Restore the original oracle price:** Submit price updates of `999 ether` from both compromised sources. All three sources now report `999 ether`, restoring the original median price.

5. **Approve the exchange to transfer the NFT:** Call `nft.approve(address(exchange), tokenId)` to authorize the exchange to transfer the NFT back from the player.

6. **Sell the NFT at the restored price:** Call `exchange.sellOne(tokenId)`. The exchange reads the restored oracle price and transfers `999 ETH` to the player in exchange for the NFT.

7. **Recover the exchange's remaining ETH:** Transfer the received `999 ETH` to the recovery address, leaving the exchange with zero ETH.

## Why the Victim Loses Funds

The exchange relies on the oracle's median price to determine the amount of ETH required to purchase an NFT and the amount paid when an NFT is sold.

By compromising two of the three trusted sources, the attacker can manipulate the median price without directly compromising the exchange.

The attacker purchases an NFT when the reported price is zero, restores the reported price to `999 ETH`, and sells the NFT back at the restored price.

Consequently, the exchange loses its entire `999 ETH` balance, while the attacker recovers the funds through the sale.

## Remediation

The oracle should not rely on a small set of trusted sources whose compromise gives an attacker control over the reported price.

Possible improvements include:

- Strengthen private-key security through secure key management, hardware security modules, and key rotation.
- Increase the number and independence of oracle sources so that compromising a small subset cannot manipulate the reported price.
- Introduce price deviation limits and anomaly detection to reject suspicious updates.
- Use independent price feeds and robust aggregation mechanisms to reduce dependence on individual reporters.

The exchange should also consider safeguards against executing trades at implausible or manipulated oracle prices.

## Key Lesson

An oracle's security depends not only on its aggregation mechanism but also on the integrity and independence of its data sources.

A median price does not guarantee manipulation resistance when an attacker controls enough of the sources contributing to that median.