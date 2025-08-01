/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "transfer" of "RecoveryController".
 */
contract Transfer_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_transfer(address user, address to, uint256 initialBalance, uint256 amount) public {
        // Given "user" has "initialBalance" tokens.
        deal(address(recoveryControllerExtension), user, initialBalance);

        // When: "user" transfers "amount" to "to".
        // Then: Transaction should revert with "NoTransfersAllowed".
        vm.prank(user);
        vm.expectRevert(NoTransfersAllowed.selector);
        recoveryControllerExtension.transfer(to, amount);
    }

    function testFuzz_Revert_transferFrom(
        address caller,
        address user,
        address to,
        uint256 allowance,
        uint256 initialBalance,
        uint256 amount
    ) public {
        // Given "user" has "initialBalance" tokens.
        deal(address(recoveryControllerExtension), user, initialBalance);
        // And: "caller" has allowance of "allowance" from "user"
        vm.prank(user);
        recoveryControllerExtension.approve(caller, allowance);

        // When: "caller" transfers "amount" from "user" to "to".
        // Then: Transaction should revert with "NoTransfersAllowed".
        vm.prank(caller);
        vm.expectRevert(NoTransfersAllowed.selector);
        recoveryControllerExtension.transferFrom(user, to, amount);
    }
}
