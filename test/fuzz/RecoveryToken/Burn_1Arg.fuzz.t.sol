/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryToken_Fuzz_Test} from "./_RecoveryToken.fuzz.t.sol";

import {stdError} from "../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "burn" of "RecoveryToken".
 */
contract Burn_1Arg_RecoveryToken_Fuzz_Test is RecoveryToken_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryToken_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_burn_1arg_InsufficientBalance(address user, uint256 initialBalance, uint256 amount)
        public
    {
        // Given "user" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), user, initialBalance);
        // And: "amount" is bigger as "initialBalance".
        vm.assume(amount > initialBalance);

        // When: "user" burns "amount".
        // Then: Transaction should revert with "arithmeticError".
        vm.prank(user);
        vm.expectRevert(stdError.arithmeticError);
        recoveryTokenExtension.burn(amount);
    }

    function testFuzz_Success_burn_1arg(address user, uint256 initialBalance, uint256 amount) public {
        // Given "user" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), user, initialBalance);
        // And: "amount" is smaller or equal as "initialBalance".
        vm.assume(amount <= initialBalance);

        // When: "user" burns "amount".
        vm.prank(user);
        recoveryTokenExtension.burn(amount);

        // Then: Balance of "user" should decrease with "amount".
        assertEq(recoveryTokenExtension.balanceOf(user), initialBalance - amount);
    }
}
