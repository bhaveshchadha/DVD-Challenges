# Free Rider

## Vulnerability

When a User buys multiple nft using buy many external fn  , internally the market place runs _buyOne private fn , which in turn sends the nft to the caller but it runs if (msg.value < priceToPay) {
            revert InsufficientPayment();
        } 

which creates the main vulnerability, for all n number of nfts sold, the if condition checks for the same msg.value , hence this accounting error allows a user to buy n number of nfts for price of 1 NFT and thus losing and also ether because
  payable(_token.ownerOf(tokenId)).sendValue(priceToPay); in _buyOne sends markets eth to the sender .


## Root Cause
Accounting contraints not checks  for each nft bought individually allowing an attacker to buy multiple nfts for price of 1 .
## Broken Invariant / Assumption
Assumption was that for each nft bough user pays a price but due to incorrect accounting checks user can buy ,ultiple nfts for price of 1 .
Other assumption is that Eth being sent to seller are the ones provided by buyer but they after the first nft bought are actually sent by marketplace contract itself
## Attack Path

1.We create a attacker contract which contains the callback fn swap runs
2.when swap runs we ask for ether equivalent to price of one NFT 
3.Swap runs the callback where we buy multiple nfts for price of 1 by running buy many() which runs internal fn _buyOne mutiple times which contains the faulty accounting logic , which in turns sends eth of it's own to seller
4.After that we transfer nfts bought to recovery manager which in turn runs onERC721Received and sends us our bounty 

## Why the Victim Loses Funds
Design implementation works for one individual operation but not when same operation is done multiple times in 1 txn , allowing attacker to buy multiple nfts to bought for price of 1 , and lack of checks for whose assets are being sent to seller, leads to drainage of eth from the marketplace
## Remediation
For each nft being bought check eth sent indivdually, and make sure the seller only sends eth sent by the buyer and not from it's own contract itself
## Key Lesson

A fn may work individually once but multiple times leads to an invalid state , the flow of assets should always be from the source and not from the protocol itself (unless it's the source)