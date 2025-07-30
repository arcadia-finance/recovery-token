/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { ControllerState } from "../../utils/Types.sol";
import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "finaliseTermination" of "RecoveryController".
 */
contract FinaliseTermination_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_finaliseTermination_NonOwner(address unprivilegedAddress) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" calls "finaliseTermination".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.finaliseTermination();
    }

    function test_Revert_finaliseTermination_NotInitialised() public {
        // Given: The termination is not initialised.
        assertEq(recoveryControllerExtension.terminationTimestamp(), 0);

        // When: "owner" calls "finaliseTermination".
        // Then: Transaction should revert with "TerminationCoolDownPeriodNotPassed".
        vm.prank(users.owner);
        vm.expectRevert(TerminationCoolDownPeriodNotPassed.selector);
        recoveryControllerExtension.finaliseTermination();
    }

    function testFuzz_Revert_finaliseTermination_TerminationCoolDownPeriodNotPassed(
        uint32 terminationTimestamp,
        uint32 currentTime
    ) public {
        // Given: The termination is initialised at "terminationTimestamp".
        terminationTimestamp = uint32(bound(terminationTimestamp, 1, type(uint32).max - 1 weeks + 1));
        recoveryControllerExtension.setTerminationTimestamp(terminationTimestamp);

        // And: Less then "COOLDOWN_PERIOD" (1 week) passed.
        currentTime = uint32(bound(currentTime, terminationTimestamp, terminationTimestamp + 1 weeks - 1));
        vm.warp(currentTime);

        // When: "owner" calls "finaliseTermination".
        // Then: Transaction should revert with "TerminationCoolDownPeriodNotPassed".
        vm.prank(users.owner);
        vm.expectRevert(TerminationCoolDownPeriodNotPassed.selector);
        recoveryControllerExtension.finaliseTermination();
    }

    function testFuzz_Success_finaliseTermination(
        uint32 terminationTimestamp,
        uint32 currentTime,
        ControllerState memory controller
    ) public {
        // Given: The termination is initialised at "terminationTimestamp".
        terminationTimestamp = uint32(bound(terminationTimestamp, 1, type(uint32).max - 1 weeks));
        recoveryControllerExtension.setTerminationTimestamp(terminationTimestamp);

        // And: More then "COOLDOWN_PERIOD" (1 week) passed.
        currentTime = uint32(bound(currentTime, terminationTimestamp + 1 weeks, type(uint32).max));
        vm.warp(currentTime);

        // And: State is persisted.
        setControllerState(controller);

        // When: "owner" calls "finaliseTermination".
        vm.prank(users.owner);
        vm.expectEmit(address(recoveryControllerExtension));
        emit ActivationSet(false);
        recoveryControllerExtension.finaliseTermination();

        // Then: "recoveryController" is not active.
        assertFalse(recoveryControllerExtension.active());

        // Then: "underlyingToken" balance of "recoveryController" becomes zero.
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), 0);

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT);
    }
}
