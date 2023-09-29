/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "./_RecoveryController.fuzz.t.sol";

import {stdError} from "../../../lib/forge-std/src/StdError.sol";

import {UserState, ControllerState} from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the function "depositRecoveryTokens" of "RecoveryController".
 */
contract DepositRecoveryTokens_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_depositRecoveryTokens_NotActive(address user, uint256 amount) public {
        // Given: "RecoveryController" is not active.

        // When: "user" calls "depositRecoveryTokens" with "amount".
        // Then: Transaction reverts with "NotActive".
        vm.prank(user);
        vm.expectRevert(NotActive.selector);
        recoveryControllerExtension.depositRecoveryTokens(amount);
    }

    function testFuzz_Revert_depositRecoveryTokens_ZeroAmount(address user) public {
        // Given: "RecoveryController" is active.
        recoveryControllerExtension.setActive(true);

        // When: "user" calls "depositRecoveryTokens" with 0 amount.
        // Then: Transaction reverts with "DRT: DepositAmountZero".
        vm.prank(user);
        vm.expectRevert(DepositAmountZero.selector);
        recoveryControllerExtension.depositRecoveryTokens(0);
    }

    function testFuzz_Revert_depositRecoveryTokens_InsufficientBalance(uint256 amount, UserState memory user) public {
        // Given: "RecoveryController" is active.
        recoveryControllerExtension.setActive(true);
        // And: "amount" is strictly bigger as "user.balanceRT".
        user.balanceRT = bound(user.balanceRT, 0, type(uint256).max - 1);
        amount = bound(amount, user.balanceRT + 1, type(uint256).max);

        // When: "user" calls "depositRecoveryTokens" with "amount".
        // Then: Transaction reverts with "arithmeticError".
        vm.prank(user.addr);
        vm.expectRevert(stdError.arithmeticError);
        recoveryControllerExtension.depositRecoveryTokens(amount);
    }

    function testFuzz_Success_depositRecoveryTokens_NoInitialPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: "user" has no initial position. (test-condition NoInitialPosition)
        user.balanceWRT = 0;
        user.redeemablePerRTokenLast = 0;
        user.redeemed = 0;

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_depositRecoveryTokens_ZeroAmount).
        uint256 minAmount = 1;
        // And: "amount" does not revert/overflow.
        amount = givenValidDepositAmount(amount, minAmount, type(uint256).max, user, controller);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // And: "user" has approved "recoveryController" with at least "amount".
        vm.prank(user.addr);
        recoveryToken.approve(address(recoveryControllerExtension), amount);

        // When: "user" calls "recoveryToken".
        vm.prank(user.addr);
        recoveryControllerExtension.depositRecoveryTokens(amount);

        // Then: "user" state variables are updated.
        assertEq(
            recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), controller.redeemablePerRTokenGlobal
        );
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT - amount);
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), amount);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT + amount);
        assertEq(wrappedRecoveryToken.totalSupply(), controller.supplyWRT + amount);
    }

    function testFuzz_Success_depositRecoveryTokens_WithInitialPosition_NonRecoveredPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: "user" has initial position. (test-condition InitialPosition)
        vm.assume(user.balanceWRT > 0);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_depositRecoveryTokens_ZeroAmount).
        // And: The position is not fully covered (test-condition NonRecoveredPosition).
        // -> "openPosition + amount" is strictly greater as "redeemable".
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        uint256 minAmount = (openPosition <= redeemable) ? (redeemable - openPosition + 1) : 1;
        // And: "amount" does not revert/overflow.
        amount = givenValidDepositAmount(amount, minAmount, type(uint256).max, user, controller);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // And: "user" has approved "recoveryController" with at least "amount".
        vm.prank(user.addr);
        recoveryToken.approve(address(recoveryControllerExtension), amount);

        // When: "user" calls "recoveryToken".
        vm.prank(user.addr);
        recoveryControllerExtension.depositRecoveryTokens(amount);

        // Then: "user" state variables are updated.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), user.balanceWRT + amount);
        assertEq(recoveryControllerExtension.redeemed(user.addr), user.redeemed + redeemable);
        assertEq(
            recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), controller.redeemablePerRTokenGlobal
        );
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT - amount);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(wrappedRecoveryToken.totalSupply(), controller.supplyWRT + amount);
        assertEq(
            recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT + amount - redeemable
        );
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - redeemable);
    }

    function testFuzz_Success_depositRecoveryTokens_WithInitialPosition_FullyRecoveredPosition_LastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: "user" has an initial position. (test-condition InitialPosition)
        vm.assume(user.balanceWRT > 0);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_depositRecoveryTokens_ZeroAmount).
        uint256 minAmount = 1;
        // And: The position is fully covered (test-condition NonRecoveredPosition).
        // -> "openPosition + amount" is smaller or equal as "redeemable".
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= type(uint256).max - minAmount);
        vm.assume(openPosition + minAmount <= redeemable);
        uint256 maxAmount = redeemable - openPosition;
        // And: "amount" does not revert/overflow.
        amount = givenValidDepositAmount(amount, minAmount, maxAmount, user, controller);

        // And: "totalSupply" equals the balance of the user (test-condition LastPosition).
        controller.supplyWRT = user.balanceWRT;

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed - amount);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // And: "user" has approved "recoveryController" with at least "amount".
        vm.prank(user.addr);
        recoveryToken.approve(address(recoveryControllerExtension), amount);

        // When: "user" calls "recoveryToken".
        vm.prank(user.addr);
        recoveryControllerExtension.depositRecoveryTokens(amount);

        // Then: "user" position is closed.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT - amount);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition + amount);

        // And: "controller" state variables are updated.
        assertEq(wrappedRecoveryToken.totalSupply(), 0);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), 0);

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT - openPosition - amount);
    }

    function testFuzz_Success_depositRecoveryTokens_WithInitialPosition_FullyRecoveredPosition_NotLastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: "user" has initial position. (test-condition InitialPosition)
        vm.assume(user.balanceWRT > 0);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_depositRecoveryTokens_ZeroAmount).
        uint256 minAmount = 1;
        // And: The position is fully covered (test-condition NonRecoveredPosition).
        // -> "openPosition + amount" is smaller or equal as "redeemable".
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= type(uint256).max - minAmount);
        vm.assume(openPosition + minAmount <= redeemable);
        uint256 maxAmount = redeemable - openPosition;
        // And: "amount" does not revert/overflow.
        amount = givenValidDepositAmount(amount, minAmount, maxAmount, user, controller);

        // And: "totalSupply" is strictly bigger as the balance of the user (test-condition NotLastPosition).
        vm.assume(user.balanceWRT < type(uint256).max);
        controller.supplyWRT = bound(controller.supplyWRT, user.balanceWRT + 1, type(uint256).max);

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed);
        uint256 surplus = user.redeemed + redeemable - user.balanceWRT - amount;
        // And: Assume "delta" does not overflow (unrealistic big numbers).
        vm.assume(surplus <= type(uint256).max / 1e18);
        uint256 delta = surplus * 1e18 / (controller.supplyWRT - user.balanceWRT);
        // And: Assume "redeemablePerRTokenGlobal" does not overflow (unrealistic big numbers).
        vm.assume(controller.redeemablePerRTokenGlobal <= type(uint256).max - delta);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // And: "user" has approved "recoveryController" with at least "amount".
        vm.prank(user.addr);
        recoveryToken.approve(address(recoveryControllerExtension), amount);

        // When: "user" calls "recoveryToken".
        vm.prank(user.addr);
        recoveryControllerExtension.depositRecoveryTokens(amount);

        // Then: "user" position is closed.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT - amount);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition + amount);

        // And: "controller" state variables are updated.
        assertEq(wrappedRecoveryToken.totalSupply(), controller.supplyWRT - user.balanceWRT);
        assertEq(recoveryControllerExtension.redeemablePerRTokenGlobal(), controller.redeemablePerRTokenGlobal + delta);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(
            underlyingToken.balanceOf(address(recoveryControllerExtension)),
            controller.balanceUT - openPosition - amount
        );

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }
}
