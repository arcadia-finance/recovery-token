/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { ControllerState, UserState } from "../../utils/Types.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "depositUnderlying" of "RecoveryController".
 */
contract DepositUnderlying_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_depositUnderlying_NotActive(address depositor, uint256 amount) public {
        // Given: "RecoveryController" is not active.

        // When: A "depositor" deposits "amount" of "underlyingToken".
        // Then: The transaction reverts with "NotActive".
        vm.prank(depositor);
        vm.expectRevert(NotActive.selector);
        recoveryControllerExtension.depositUnderlying(amount);
    }

    function testFuzz_Revert_depositUnderlying_ZeroAmount(address depositor) public {
        // Given: "RecoveryController" is active.
        recoveryControllerExtension.setActive(true);

        // When: A "depositor" deposits "amount" of "underlyingToken".
        // Then: The transaction reverts with "DepositAmountZero".
        vm.prank(depositor);
        vm.expectRevert(DepositAmountZero.selector);
        recoveryControllerExtension.depositUnderlying(0);
    }

    function testFuzz_Revert_depositUnderlying_NoOpenPositions(
        address depositor,
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: The protocol is active.
        controller.active = true;

        // And: "amount" is non-zero.
        vm.assume(amount > 0);

        // And: There are no open positions on the "recoveryController".
        controller.supplyWRT = 0;

        // And: state is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: A "depositor" deposits 0 of "underlyingToken".
        // Then: The transaction reverts with "" (division by zero in Solmate lib).
        vm.prank(depositor);
        vm.expectRevert(bytes(""));
        recoveryControllerExtension.depositUnderlying(amount);
    }

    function testFuzz_Success_depositUnderlying(
        address depositor,
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "user" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: "depositor" is not "user" or "recoveryController".
        vm.assume(depositor != address(recoveryControllerExtension));
        vm.assume(depositor != user.addr);

        // And: "amount" is non-zero.
        vm.assume(amount > 0);

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: "controller.supplyWRT" is non-zero.
        vm.assume(controller.supplyWRT > 0);

        // And: Balance "controller.supplyUT" does not overflow (ERC20 Invariant).
        vm.assume(controller.balanceUT < type(uint256).max);
        amount = bound(amount, 1, type(uint256).max - controller.balanceUT);

        // And: Assume "delta" does not overflow (unrealistic big numbers).
        amount = bound(amount, 1, type(uint256).max / 1e18);
        uint256 delta = amount * 1e18 / controller.supplyWRT;
        // And: Assume "redeemablePerRTokenGlobal" does not overflow (unrealistic big numbers).
        vm.assume(controller.redeemablePerRTokenGlobal <= type(uint256).max - delta);
        // And: "redeemable" does not overflow (unrealistic big numbers).
        uint256 userDelta = controller.redeemablePerRTokenGlobal + delta - user.redeemablePerRTokenLast;
        if (userDelta > 0) {
            vm.assume(user.balanceWRT <= type(uint256).max / userDelta);
        }

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // Cache redeemable before call.
        uint256 userRedeemableLast = recoveryControllerExtension.previewRedeemable(user.addr);

        // When: A "depositor" deposits "amount" of "underlyingToken".
        deal(address(underlyingToken), depositor, amount);
        vm.startPrank(depositor);
        underlyingToken.approve(address(recoveryControllerExtension), amount);
        recoveryControllerExtension.depositUnderlying(amount);
        vm.stopPrank();

        // Then: "controller" state variables are updated.
        assertEq(recoveryControllerExtension.redeemablePerRTokenGlobal(), controller.redeemablePerRTokenGlobal + delta);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT + amount);

        // And: The total amount deposited (minus rounding error) is claimable by all rToken Holders.
        // No direct function on the contract -> calculate actualTotalRedeemable of last deposit.
        uint256 actualTotalRedeemable = recoveryControllerExtension.totalSupply()
            * (recoveryControllerExtension.redeemablePerRTokenGlobal() - controller.redeemablePerRTokenGlobal) / 1e18;
        uint256 maxRoundingError = controller.supplyWRT / 1e18 + 1;
        assertApproxEqAbs(actualTotalRedeemable, amount, maxRoundingError);

        // And: A proportional share of "amount" is redeemable by "user".
        uint256 actualUserRedeemable = recoveryControllerExtension.previewRedeemable(user.addr) - userRedeemableLast;
        // ToDo: use Full Math library proper MulDiv.
        if (user.balanceWRT != 0) vm.assume(amount <= type(uint256).max / user.balanceWRT);
        // For the lower bound we start from the lowerBound of the total deposited amount and calculate the relative share rounded down.
        uint256 lowerBoundTotal = maxRoundingError < amount ? amount - maxRoundingError : 0;
        uint256 lowerBoundUser = lowerBoundTotal.mulDivDown(user.balanceWRT, controller.supplyWRT);
        // For the upper bound we start from the full amount of the total deposited amount and calculate the relative share rounded up.
        uint256 upperBoundUser = amount.mulDivUp(user.balanceWRT, controller.supplyWRT);
        assertLe(lowerBoundUser, actualUserRedeemable);
        assertLe(actualUserRedeemable, upperBoundUser);
    }
}
