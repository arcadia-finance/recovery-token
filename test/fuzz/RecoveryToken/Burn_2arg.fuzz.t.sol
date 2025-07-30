/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryToken_Fuzz_Test } from "./_RecoveryToken.fuzz.t.sol";
import { stdError } from "../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "burn" of "RecoveryToken".
 */
contract Burn_2arg_RecoveryToken_Fuzz_Test is RecoveryToken_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryToken_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_burn_2arg_NonRecoveryController(
        address unprivilegedAddress,
        address user,
        uint256 initialBalance,
        uint256 amount
    ) public {
        // Given: Caller is not the "recoveryController".
        vm.assume(unprivilegedAddress != address(recoveryController));
        // And: "user" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), user, initialBalance);

        // When: "unprivilegedAddress" burns "amount" of "user".
        // Then: Transaction should revert with "NotRecoveryController".
        vm.prank(unprivilegedAddress);
        vm.expectRevert(NotRecoveryController.selector);
        recoveryTokenExtension.burn(user, amount);
    }

    function testFuzz_Revert_burn_2arg_InsufficientBalance(address user, uint256 initialBalance, uint256 amount)
        public
    {
        // Given "user" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), user, initialBalance);
        // And: "amount" is bigger as "initialBalance".
        vm.assume(amount > initialBalance);

        // When: "recoveryController" burns "amount" of "user".
        // Then: Transaction should revert with "arithmeticError".
        vm.prank(address(recoveryController));
        vm.expectRevert(stdError.arithmeticError);
        recoveryTokenExtension.burn(user, amount);
    }

    function testFuzz_Success_burn_2arg(address user, uint256 initialBalance, uint256 amount) public {
        // Given "user" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), user, initialBalance);
        // And: "amount" is smaller or equal as "initialBalance".
        vm.assume(amount <= initialBalance);

        // When: "recoveryController" burns "amount" of "user".
        vm.prank(address(recoveryController));
        recoveryTokenExtension.burn(user, amount);

        // Then: Balance of "user" should decrease with "amount".
        assertEq(recoveryTokenExtension.balanceOf(user), initialBalance - amount);
    }
}
