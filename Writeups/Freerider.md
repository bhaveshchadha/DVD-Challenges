# Free Rider

## Vulnerability

The `FreeRiderNFTMarketplace` contract contains two vulnerabilities in its NFT purchasing logic that allow an attacker to acquire all six NFTs while retaining enough ETH to repay a Uniswap V2 flash swap.

First, the marketplace's `buyMany()` function allows multiple NFTs to be purchased while checking the same `msg.value` against each NFT's individual price. It does not account for the payment already used for previous purchases. Consequently, an attacker can purchase all six NFTs, each priced at `15 ETH`, by paying only `15 ETH` instead of the intended total of `90 ETH`.

Second, the marketplace transfers each NFT to the buyer before determining the address to which the purchase payment should be sent. Since the NFT's owner has already changed, `token.ownerOf(tokenId)` returns the buyer's address rather than the original seller's address. Consequently, the marketplace sends the purchase payment back to the buyer.

An attacker can combine these vulnerabilities with a Uniswap V2 flash swap to acquire all six NFTs, receive the marketplace's ETH payments, and repay the borrowed WETH. The NFTs can then be transferred to the recovery manager to claim the `45 ETH` bounty.

## Root Cause

The root cause is incorrect payment validation and incorrect seller identification in the marketplace's NFT purchasing logic.

The `buyMany()` function repeatedly validates the same `msg.value` without accounting for the cumulative cost of purchasing multiple NFTs.

Additionally, the marketplace determines the NFT owner after transferring it to the buyer. This causes the payment intended for the original seller to be sent to the new owner instead.

## Broken Invariant / Assumption

**Invariant**

The marketplace must collect the full purchase price for every NFT transferred to a buyer and transfer the corresponding payment to the original seller.

**Violation**

The attacker purchases all six NFTs by supplying only `15 ETH`, because the marketplace does not account for cumulative payment requirements.

Furthermore, after transferring each NFT to the attacker, the marketplace uses the updated owner to determine the payment recipient. This results in the purchase payments being sent back to the attacker instead of the original seller.

## Attack Path

1. **Deploy an attacker contract:** Create an `Attacker` contract that implements `uniswapV2Call()` to receive the flash swap and `onERC721Received()` to accept the purchased NFTs.

2. **Initiate a Uniswap V2 flash swap:** Call `uniswapPair.swap()` to borrow `15 WETH`, specifying the attacker contract as the recipient. This invokes the attacker's `uniswapV2Call()` callback.

3. **Unwrap the borrowed WETH:** Inside the callback, call `weth.withdraw(amount0)` to convert the borrowed `15 WETH` into `15 ETH`, which is required by the marketplace.

4. **Purchase all six NFTs:** Call `marketplace.buyMany()` with all six token IDs and `15 ETH`. Due to the payment-validation vulnerability, the same `msg.value` satisfies the individual price check for every NFT.

5. **Receive the marketplace payments:** During each purchase, the marketplace transfers the NFT to the attacker before determining the payment recipient. Consequently, `token.ownerOf(tokenId)` returns the attacker's address, causing the marketplace to send the `15 ETH` purchase payment back to the attacker. Across six purchases, the attacker receives `90 ETH`.

6. **Repay the flash swap:** Calculate the required repayment, including Uniswap V2's 0.3% swap fee:

   ```solidity
   uint256 repayment = (amount0 * 1000) / 997 + 1;
   ```

   Wrap the required ETH back into WETH using `weth.deposit()` and transfer the WETH to the Uniswap pair.

7. **Transfer the NFTs to the recovery manager:** Encode the player's address using `abi.encode(player)` and transfer all six NFTs to the `FreeRiderRecoveryManager` using `safeTransferFrom()`.

8. **Claim the bounty:** Once the recovery manager receives all six NFTs, it releases the `45 ETH` bounty to the designated player address.

## Why the Victim Loses Funds

The marketplace's incorrect payment validation allows the attacker to purchase all six NFTs for only `15 ETH` instead of the intended `90 ETH`.

Furthermore, the marketplace sends the purchase payments to the attacker because it determines the NFT owner after transferring each NFT. This allows the attacker to receive `90 ETH` from the marketplace while acquiring all six NFTs.

The attacker uses a portion of these funds to repay the `15 WETH` flash swap, including the required fee, and transfers the NFTs to the recovery manager to claim the additional `45 ETH` bounty.

Consequently, the marketplace loses its NFTs and a significant portion of its ETH balance, while the attacker successfully completes the recovery and earns the bounty.

## Remediation

The marketplace should address both vulnerabilities:

1. **Correct payment validation:** `buyMany()` must account for the cumulative price of all NFTs being purchased. It should ensure that the total payment covers the combined price of all selected NFTs rather than repeatedly checking the unchanged `msg.value`.

2. **Preserve the original seller address:** The marketplace should retrieve and store the original NFT owner's address before transferring the NFT. The payment must then be sent to that stored seller address rather than querying `ownerOf()` after the transfer.

## Key Lesson

External calls and state changes can alter the values returned by contract functions. In particular, transferring an NFT changes its owner, so querying `ownerOf()` after the transfer may return a completely different address.

Additionally, `msg.value` represents the total ETH supplied to a payable function call; it does not decrease as individual purchases are processed within a loop.

Smart contracts must account for cumulative payments and preserve relevant state before performing operations that can change it.