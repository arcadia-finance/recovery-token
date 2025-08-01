/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { ControllerState, UserState } from "../../utils/Types.sol";
import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unstakeRecoveryTokens" of "RecoveryController".
 */
contract UnstakeRecoveryTokens_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_unstakeRecoveryTokens_NotActive(address user, uint256 amount) public {
        // Given: "RecoveryController" is not active.

        // When: "user" calls "unstakeRecoveryTokens" with "amount".
        // Then: Transaction reverts with "NotActive".
        vm.prank(user);
        vm.expectRevert(NotActive.selector);
        recoveryControllerExtension.unstakeRecoveryTokens(amount);
    }

    function testFuzz_Revert_unstakeRecoveryTokens_ZeroAmount(address user) public {
        // Given: "RecoveryController" is active.
        recoveryControllerExtension.setActive(true);

        // When: "user" calls "unstakeRecoveryTokens" with 0 amount.
        // Then: Transaction reverts with "SRT: ZeroAmount".
        vm.prank(user);
        vm.expectRevert(ZeroAmount.selector);
        recoveryControllerExtension.unstakeRecoveryTokens(0);
    }

    function testFuzz_Success_unstakeRecoveryTokens_NonRecoveredPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_unstakeRecoveryTokens_ZeroAmount).
        uint256 minAmount = 1;
        // And: The position is not fully covered (test-condition NonRecoveredPosition).
        // -> "openPosition is strictly greater as "redeemable" + amount".
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(redeemable <= type(uint256).max - minAmount);
        vm.assume(openPosition > redeemable + minAmount);
        uint256 maxAmount = openPosition - redeemable - 1;
        amount = bound(amount, minAmount, maxAmount);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "user" calls "unstakeRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.unstakeRecoveryTokens(amount);

        // Then: "user" state variables are updated.
        assertEq(stakedRecoveryToken.balanceOf(user.addr), user.balanceSRT - amount);
        assertEq(recoveryControllerExtension.redeemed(user.addr), user.redeemed + redeemable);
        assertEq(
            recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), controller.redeemablePerRTokenGlobal
        );
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT + amount);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(stakedRecoveryToken.totalSupply(), controller.supplySRT - amount);
        assertEq(
            recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - amount - redeemable
        );
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - redeemable);
    }

    function testFuzz_Success_unstakeRecoveryTokens_FullyRecoveredPosition_WithWithdrawal_LastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        // And: The position is fully covered (test-condition FullyRecoveredPosition).
        // But only after a non-zero withdrawal of rTokens (test-condition WithWithdrawal).
        // -> "openPosition is strictly greater as "redeemable".
        // -> "openPosition is smaller or equal to "redeemable + amount".
        vm.assume(openPosition > redeemable);
        uint256 minAmount = openPosition - redeemable;
        amount = bound(amount, minAmount, type(uint256).max);

        // And: "totalSupply" equals the balance of the user (test-condition LastPosition).
        controller.supplySRT = user.balanceSRT;

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "user" calls "unstakeRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.unstakeRecoveryTokens(amount);

        // Then: "user" state variables are updated.
        assertEq(stakedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT + openPosition - redeemable);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(stakedRecoveryToken.totalSupply(), controller.supplySRT - user.balanceSRT);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), 0);

        // And: "underlyingToken" balance of "owner" increases with redeemable.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT - redeemable);
    }

    function testFuzz_Success_unstakeRecoveryTokens_FullyRecoveredPosition_WithWithdrawal_NotLastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        // And: The position is fully covered (test-condition FullyRecoveredPosition).
        // But only after a non-zero withdrawal of rTokens (test-condition WithWithdrawal).
        // -> "openPosition is strictly greater as "redeemable".
        // -> "openPosition is smaller or equal to "redeemable + amount".
        vm.assume(openPosition > redeemable);
        uint256 minAmount = openPosition - redeemable;
        amount = bound(amount, minAmount, type(uint256).max);

        // And: "totalSupply" is strictly bigger as the balance of the user (test-condition NotLastPosition).
        vm.assume(user.balanceSRT < type(uint256).max);
        controller.supplySRT = bound(controller.supplySRT, user.balanceSRT + 1, type(uint256).max);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "user" calls "unstakeRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.unstakeRecoveryTokens(amount);

        // Then: "user" state variables are updated.
        assertEq(stakedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT + openPosition - redeemable);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(stakedRecoveryToken.totalSupply(), controller.supplySRT - user.balanceSRT);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - redeemable);

        // And: "underlyingToken" balance of "owner" does not increase.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }

    function testFuzz_Success_unstakeRecoveryTokens_FullyRecoveredPosition_WithoutWithdrawal_LastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-condition FullyRecoveredPosition).
        // Before even rTokens are withdrawn (test-condition WithoutWithdrawal).
        // -> "openPosition is smaller or equal to "redeemable".
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_unstakeRecoveryTokens_ZeroAmount).
        amount = bound(amount, 1, type(uint256).max);

        // And: "totalSupply" equals the balance of the user (test-condition LastPosition).
        controller.supplySRT = user.balanceSRT;

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "user" calls "unstakeRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.unstakeRecoveryTokens(amount);

        // Then: "user" state variables are updated.
        assertEq(stakedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(stakedRecoveryToken.totalSupply(), 0);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), 0);

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT - openPosition);
    }

    function testFuzz_Success_unstakeRecoveryTokens_FullyRecoveredPosition_WithoutWithdrawal_NotLastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-condition FullyRecoveredPosition).
        // Before even rTokens are withdrawn (test-condition WithoutWithdrawal).
        // -> "openPosition is smaller or equal to "redeemable".
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_unstakeRecoveryTokens_ZeroAmount).
        amount = bound(amount, 1, type(uint256).max);

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

        // When: "user" calls "unstakeRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.unstakeRecoveryTokens(amount);

        // Then: "user" state variables are updated.
        assertEq(stakedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(stakedRecoveryToken.totalSupply(), controller.supplySRT - user.balanceSRT);
        assertEq(recoveryControllerExtension.redeemablePerRTokenGlobal(), controller.redeemablePerRTokenGlobal + delta);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - openPosition);

        // And: "underlyingToken" balance of "owner" does not increase.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }
}
