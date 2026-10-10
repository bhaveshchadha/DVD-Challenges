# Backdoor

## Vulnerability

Wallet Registry incentivizes wallet creation of their team by providing them with 10 dvt when they register an wallet . SafeProxyFactory::createProxyWithCallback is used for registration . Any arbitrary address can start the registration for an beneficiary address and during initialization run malicious function in proxies storage which approves token on the behalf of the newly created proxy, which will be sent 10 dvt in proxy created. This approval can then be used to pull procies token and send them to recovery address .

## Root Cause

Any arbitrary address can register wallet on behalf of a beneficiary and during it's initilization approve any attacker controlled address to be able to pull proxy's token later.

## Broken Invariant / Assumption
Wallet factory using wallet registration creates an Proxy . Nobody should be able to approve tokens on this proxies behalf but during initialization of this proxy an Attacker can run any arbitrary function on proxy's storage to approve an address to be able to transfer tokens on it's behalf .

## Attack Path

1. Attacker for all the users using walletFactory.createProxyWithCallback(address _singleton,
            bytes initializer,
            uint256 saltNonce,
            IProxyCreationCallback callback) 
            public returns (SafeProxy proxy) registers them by passing a malicous intializer
2. In Initializor attacker passes an malicous to address which runs for storage of proxy created and approves some token on it's behalf i.e.
allowance[SafeProxy][player] = 10 DVT
3. proxyCreated sends the wallet/proxy address the reward tokens it is entiled to
4. After proxyCreated returns control attacker then uses previously approved tokens to transfer them to our recovery address

## Why the Victim Loses Funds
Victim lost fund because they did not restrict what is allowed during initialization , allowing attacker to approve tokens on proxies behalf during intialization even tho anybody can trigger this intilization on the beneficiary's behalf ,which also receives DVT tokens in proxy created .
## Remediation

Restrict what is allowed during initialization , One simple way is to make sure no other contracts code runs on proxies storage during unless explicitly requiredinitialization . By making checks like if(to!="") revert. Also make sure that only beneficiary or accounts with specifc roles can register on beneficary behalf and validate it.


## Key Lesson
A trusted wallet facotry doesnot guarantee that wallet is safely initialized . Validate both the deployment path and safety of resulting wallet's initial state