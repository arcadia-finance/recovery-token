/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "../RecoveryController.fuzz.t.sol";

/**
 * @notice Fuzz tests for the activation logic of "RecoveryController".
 */
contract ActivationLogic_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        ACTIVATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_activate_NonOwner(address unprivilegedAddress) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" calls "activate".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.activate();
    }

    function testFuzz_Revert_activate_Terminated(uint32 terminationTimestamp) public {
        // Given: The termination is already initialised.
        terminationTimestamp = uint32(bound(terminationTimestamp, 1, type(uint32).max));
        recoveryControllerExtension.setTerminationTimestamp(terminationTimestamp);

        // When: "owner" calls "activate".
        // Then: Transaction should revert with "ControllerTerminated".
        vm.prank(users.owner);
        vm.expectRevert(ControllerTerminated.selector);
        recoveryControllerExtension.activate();
    }

    function test_Pass_activate() public {
        // Given:
        // When: "owner" calls "activate".
        vm.prank(users.owner);
        vm.expectEmit(address(recoveryControllerExtension));
        emit ActivationSet(true);
        recoveryControllerExtension.activate();

        // Then "RecoveryController" is active.
        assertTrue(recoveryControllerExtension.active());
    }
}
