/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "./_RecoveryController.fuzz.t.sol";

import {ControllerState} from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the function "initiateTermination" of "RecoveryController".
 */
contract InitiateTermination_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_initiateTermination_NonOwner(address unprivilegedAddress) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" calls "initiateTermination".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.initiateTermination();
    }

    function testFuzz_Success_initiateTermination(uint32 currentTime, ControllerState memory controller) public {
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
}
