/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { ControllerState, UserState } from "../../utils/Types.sol";
import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "redeemUnderlying" of "RecoveryController".
 */
contract RedeemUnderlying_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_redeemUnderlying_NotActive(address caller, address user) public {
        // Given: "RecoveryController" is not active.

        // When: "caller" calls "redeemUnderlying".
        // Then: The transaction reverts with "NotActive".
        vm.prank(caller);
        vm.expectRevert(NotActive.selector);
        recoveryControllerExtension.redeemUnderlying(user);
    }

    function testFuzz_Success_redeemUnderlying_NonRecoveredPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
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

        // When: "caller" calls "redeemUnderlying" for "user".
        vm.prank(caller);
        recoveryControllerExtension.redeemUnderlying(user.addr);

        // Then: "user" state variables are updated.
        assertEq(recoveryControllerExtension.redeemed(user.addr), user.redeemed + redeemable);
        assertEq(
            recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), controller.redeemablePerRTokenGlobal
        );
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - redeemable);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - redeemable);
    }

    function testFuzz_Success_redeemUnderlying_FullyRecoveredPosition_LastPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-condition NonRecoveredPosition).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: "totalSupply" equals the balance of the user (test-condition LastPosition).
        controller.supplySRT = user.balanceSRT;

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "caller" calls "redeemUnderlying" for "user".
        vm.prank(caller);
        recoveryControllerExtension.redeemUnderlying(user.addr);

        // Then: "user" position is closed.
        assertEq(stakedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), 0);

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT - openPosition);
    }

    function testFuzz_Success_redeemUnderlying_FullyRecoveredPosition_NotLastPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-case).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: "totalSupply" is strictly bigger as the balance of the user (test-condition NotLastPosition).
        vm.assume(user.balanceSRT < type(uint256).max);
        controller.supplySRT = bound(controller.supplySRT, user.balanceSRT + 1, type(uint256).max);

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed);
        uint256 surplus = user.redeemed + redeemable - user.balanceSRT;
        // And: Assume "delta" does not overflow (unrealistic big numbers).
        vm.assume(surplus <= type(uint256).max / 1e18);
        uint256 delta = surplus * 1e18 / (controller.supplySRT - user.balanceSRT);
        // And: Assume "redeemablePerRTokenGlobal" does not overflow (unrealistic big numbers).
        vm.assume(controller.redeemablePerRTokenGlobal <= type(uint256).max - delta);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "caller" calls "redeemUnderlying" for "user".
        vm.prank(caller);
        recoveryControllerExtension.redeemUnderlying(user.addr);

        // Then: "user" position is closed.
        assertEq(stakedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        // And: "user" token balances are updated.
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - openPosition);

        // And: "underlyingToken" balance of "owner" is zero.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }
}
