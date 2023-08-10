// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {RecoveryToken} from "../src/RecoveryToken.sol";

contract RecoveryTokenTest is Test {
    RecoveryToken public recoveryToken;

    function setUp() public {
        recoveryToken = new RecoveryToken(address(0));
    }

    function test_test() public {}
}
