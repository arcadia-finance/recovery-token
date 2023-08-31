/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "../RecoveryController.fuzz.t.sol";

import {ControllerState} from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the termination logic of "RecoveryController".
 */
contract Termination_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT TERMINATION
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_initiateTermination_NonOwner(address unprivilegedAddress) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" calls "initiateTermination".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.initiateTermination();
    }

    function testFuzz_Pass_initiateTermination(uint32 currentTime, ControllerState memory controller) public {
        // Given: A certain time.
        vm.warp(currentTime);

        // And: State is persisted.
        setControllerState(controller);

        // When: "owner" calls "initiateTermination".
        vm.prank(users.owner);
        vm.expectEmit(address(recoveryControllerExtension));
        emit TerminationInitiated(currentTime);
        recoveryControllerExtension.initiateTermination();

        // Then: "terminationTimestamp" is set to "currentTime".
        assertEq(recoveryControllerExtension.terminationTimestamp(), currentTime);
    }

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

    function testFuzz_Pass_finaliseTermination(
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
