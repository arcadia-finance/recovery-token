/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "./_RecoveryController.fuzz.t.sol";

import {UserState, ControllerState} from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the function "maxRedeemable" of "RecoveryController".
 */
contract MaxRedeemable_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Success_maxRedeemable_NonRecoveredPosition(UserState memory user, ControllerState memory controller)
        public
    {
        // Given: "user" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is not fully covered (test-condition NonRecoveredPosition).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition > redeemable);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "maxRedeemable" is called for "user".
        uint256 maxRedeemable = recoveryControllerExtension.maxRedeemable(user.addr);

        // Then: Transaction returns "redeemable".
        assertEq(maxRedeemable, redeemable);
    }

    function testFuzz_Success_maxRedeemable_FullyRecoveredPosition(
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-condition NonRecoveredPosition).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "maxRedeemable" is called for "user".
        uint256 maxRedeemable = recoveryControllerExtension.maxRedeemable(user.addr);

        // Then: Transaction returns "openPosition".
        assertEq(maxRedeemable, openPosition);
    }
}
