/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "../RecoveryController.fuzz.t.sol";

import {FixedPointMathLib} from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {stdError} from "../../../lib/forge-std/src/StdError.sol";
import {StdStorage, stdStorage} from "../../../lib/forge-std/src/Test.sol";

import {UserState, ControllerState} from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the Recovery Token logic of "RecoveryController".
 */
contract RecoveryTokenLogic_Fuzz_Test is RecoveryController_Fuzz_Test {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        RECOVERY TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Pass_distributeUnderlying(uint256 redeemablePerRTokenGlobal, uint256 amount, uint256 supplyWRT)
        public
    {
        // Given: supplyWRT is non-zero.
        vm.assume(supplyWRT > 0);

        // And: New redeemablePerRTokenGlobal does not overflow.
        amount = bound(amount, 0, type(uint256).max / 1e18);
        uint256 delta = amount * 1e18 / supplyWRT;
        redeemablePerRTokenGlobal = bound(redeemablePerRTokenGlobal, 0, type(uint256).max - delta);

        // And: State is persisted.
        stdstore.target(address(recoveryControllerExtension)).sig(
            recoveryControllerExtension.redeemablePerRTokenGlobal.selector
        ).checked_write(redeemablePerRTokenGlobal);
        stdstore.target(address(recoveryControllerExtension)).sig(recoveryControllerExtension.totalSupply.selector)
            .checked_write(supplyWRT);

        // When: "amount" of "underlyingToken" is distributed.
        recoveryControllerExtension.distributeUnderlying(amount);

        // Then: "redeemablePerRTokenGlobal" is increased with "delta".
        assertEq(recoveryControllerExtension.redeemablePerRTokenGlobal(), redeemablePerRTokenGlobal + delta);
    }

    function testFuzz_Revert_depositUnderlying_NotActive(address depositor, uint256 amount) public {
        // Given: "RecoveryController" is not active.

        // When: A "depositor" deposits "amount" of "underlyingToken".
        // Then: Transaction should revert with "NotActive".
        vm.prank(depositor);
        vm.expectRevert(NotActive.selector);
        recoveryControllerExtension.depositUnderlying(amount);
    }

    function testFuzz_Revert_depositUnderlying_ZeroAmount(address depositor) public {
        // Given: "RecoveryController" is active.
        recoveryControllerExtension.setActive(true);

        // When: A "depositor" deposits "amount" of "underlyingToken".
        // Then: Transaction should revert with "DepositAmountZero".
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
        // Then: Transaction should revert with "" (solmate mulDivDown division by zero).
        vm.prank(depositor);
        vm.expectRevert(bytes(""));
        recoveryControllerExtension.depositUnderlying(amount);
    }

    function testFuzz_Pass_depositUnderlying(
        address depositor,
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: "depositor" is not "aggrievedUser" or "recoveryController".
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
        // And: "user.redeemable" does not overflow.
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

        // And: A proportional share of "amount" is redeemable by "aggrievedUser".
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

    function testFuzz_Revert_redeemUnderlying_NotActive(address caller, address aggrievedUser) public {
        // Given: "RecoveryController" is not active.

        // When: "caller" calls "redeemUnderlying".
        // Then: Transaction should revert with "NotActive".
        vm.prank(caller);
        vm.expectRevert(NotActive.selector);
        recoveryControllerExtension.redeemUnderlying(aggrievedUser);
    }

    function testFuzz_Pass_maxRedeemable_NonRecoveredPosition(UserState memory user, ControllerState memory controller)
        public
    {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is not fully covered (test-condition NonRecoveredPosition).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition > redeemable);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "maxRedeemable" is called for "aggrievedUser".
        uint256 maxRedeemable = recoveryControllerExtension.maxRedeemable(user.addr);

        // Then: Transaction returns "redeemable".
        assertEq(maxRedeemable, redeemable);
    }

    function testFuzz_Pass_maxRedeemable_FullyRecoveredPosition(
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-condition NonRecoveredPosition).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "maxRedeemable" is called for "aggrievedUser".
        uint256 maxRedeemable = recoveryControllerExtension.maxRedeemable(user.addr);

        // Then: Transaction returns "openPosition".
        assertEq(maxRedeemable, openPosition);
    }

    function testFuzz_Pass_redeemUnderlying_NonRecoveredPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is not fully covered (test-condition NonRecoveredPosition).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition > redeemable);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "caller" calls "redeemUnderlying" for "aggrievedUser".
        vm.prank(caller);
        recoveryControllerExtension.redeemUnderlying(user.addr);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(recoveryControllerExtension.redeemed(user.addr), user.redeemed + redeemable);
        assertEq(
            recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), controller.redeemablePerRTokenGlobal
        );
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - redeemable);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - redeemable);
    }

    function testFuzz_Pass_redeemUnderlying_FullyRecoveredPosition_LastPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-condition NonRecoveredPosition).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: "totalSupply" equals the balance of the user (test-condition LastPosition).
        controller.supplyWRT = user.balanceWRT;

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "caller" calls "redeemUnderlying" for "aggrievedUser".
        vm.prank(caller);
        recoveryControllerExtension.redeemUnderlying(user.addr);

        // Then: "aggrievedUser" position is closed.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), 0);

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT - openPosition);
    }

    function testFuzz_Pass_redeemUnderlying_FullyRecoveredPosition_NotLastPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-case).
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: "totalSupply" is strictly bigger as the balance of the user (test-condition NotLastPosition).
        vm.assume(user.balanceWRT < type(uint256).max);
        controller.supplyWRT = bound(controller.supplyWRT, user.balanceWRT + 1, type(uint256).max);

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed);
        uint256 surplus = user.redeemed + redeemable - user.balanceWRT;
        // And: Assume "delta" does not overflow (unrealistic big numbers).
        vm.assume(surplus <= type(uint256).max / 1e18);
        uint256 delta = surplus * 1e18 / (controller.supplyWRT - user.balanceWRT);
        // And: Assume "redeemablePerRTokenGlobal" does not overflow (unrealistic big numbers).
        vm.assume(controller.redeemablePerRTokenGlobal <= type(uint256).max - delta);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "caller" calls "redeemUnderlying" for "aggrievedUser".
        vm.prank(caller);
        recoveryControllerExtension.redeemUnderlying(user.addr);

        // Then: "aggrievedUser" position is closed.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        // And: "aggrievedUser" token balances are updated.
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - openPosition);

        // And: "underlyingToken" balance of "owner" is zero.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }

    function testFuzz_Revert_depositRecoveryTokens_NotActive(address aggrievedUser, uint256 amount) public {
        // Given: "RecoveryController" is not active.

        // When: "aggrievedUser" calls "depositRecoveryTokens" with "amount".
        // Then: Transaction reverts with "NotActive".
        vm.prank(aggrievedUser);
        vm.expectRevert(NotActive.selector);
        recoveryControllerExtension.depositRecoveryTokens(amount);
    }

    function testFuzz_Revert_depositRecoveryTokens_ZeroAmount(address aggrievedUser) public {
        // Given: "RecoveryController" is active.
        recoveryControllerExtension.setActive(true);

        // When: "aggrievedUser" calls "depositRecoveryTokens" with 0 amount.
        // Then: Transaction reverts with "DRT: DepositAmountZero".
        vm.prank(aggrievedUser);
        vm.expectRevert(DepositAmountZero.selector);
        recoveryControllerExtension.depositRecoveryTokens(0);
    }

    function testFuzz_Revert_depositRecoveryTokens_InsufficientBalance(uint256 amount, UserState memory user) public {
        // Given: "RecoveryController" is active.
        recoveryControllerExtension.setActive(true);
        // And: "amount" is strictly bigger as "user.balanceRT".
        user.balanceRT = bound(user.balanceRT, 0, type(uint256).max - 1);
        amount = bound(amount, user.balanceRT + 1, type(uint256).max);

        // When: "aggrievedUser" calls "depositRecoveryTokens" with "amount".
        // Then: Transaction reverts with "arithmeticError".
        vm.prank(user.addr);
        vm.expectRevert(stdError.arithmeticError);
        recoveryControllerExtension.depositRecoveryTokens(amount);
    }

    function testFuzz_Pass_depositRecoveryTokens_NoInitialPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
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

        // When: "aggrievedUser" calls "recoveryToken".
        vm.prank(user.addr);
        recoveryControllerExtension.depositRecoveryTokens(amount);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(
            recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), controller.redeemablePerRTokenGlobal
        );
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT - amount);
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), amount);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT + amount);
        assertEq(wrappedRecoveryToken.totalSupply(), controller.supplyWRT + amount);
    }

    function testFuzz_Pass_depositRecoveryTokens_WithInitialPosition_NonRecoveredPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
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

        // When: "aggrievedUser" calls "recoveryToken".
        vm.prank(user.addr);
        recoveryControllerExtension.depositRecoveryTokens(amount);

        // Then: "aggrievedUser" state variables are updated.
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

    function testFuzz_Pass_depositRecoveryTokens_WithInitialPosition_FullyRecoveredPosition_LastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController" or "owner".
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

        // When: "aggrievedUser" calls "recoveryToken".
        vm.prank(user.addr);
        recoveryControllerExtension.depositRecoveryTokens(amount);

        // Then: "aggrievedUser" position is closed.
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

    function testFuzz_Pass_depositRecoveryTokens_WithInitialPosition_FullyRecoveredPosition_NotLastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController" or "owner".
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

        // When: "aggrievedUser" calls "recoveryToken".
        vm.prank(user.addr);
        recoveryControllerExtension.depositRecoveryTokens(amount);

        // Then: "aggrievedUser" position is closed.
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

    function testFuzz_Revert_withdrawRecoveryTokens_NotActive(address aggrievedUser, uint256 amount) public {
        // Given: "RecoveryController" is not active.

        // When: "aggrievedUser" calls "withdrawRecoveryTokens" with "amount".
        // Then: Transaction reverts with "NotActive".
        vm.prank(aggrievedUser);
        vm.expectRevert(NotActive.selector);
        recoveryControllerExtension.withdrawRecoveryTokens(amount);
    }

    function testFuzz_Revert_withdrawRecoveryTokens_ZeroAmount(address aggrievedUser) public {
        // Given: "RecoveryController" is active.
        recoveryControllerExtension.setActive(true);

        // When: "aggrievedUser" calls "withdrawRecoveryTokens" with 0 amount.
        // Then: Transaction reverts with "WRT: WithdrawAmountZero".
        vm.prank(aggrievedUser);
        vm.expectRevert(WithdrawAmountZero.selector);
        recoveryControllerExtension.withdrawRecoveryTokens(0);
    }

    function testFuzz_Pass_withdrawRecoveryTokens_NonRecoveredPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_withdrawRecoveryTokens_ZeroAmount).
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

        // When: "aggrievedUser" calls "withdrawRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.withdrawRecoveryTokens(amount);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), user.balanceWRT - amount);
        assertEq(recoveryControllerExtension.redeemed(user.addr), user.redeemed + redeemable);
        assertEq(
            recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), controller.redeemablePerRTokenGlobal
        );
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT + amount);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(wrappedRecoveryToken.totalSupply(), controller.supplyWRT - amount);
        assertEq(
            recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - amount - redeemable
        );
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - redeemable);
    }

    function testFuzz_Pass_withdrawRecoveryTokens_FullyRecoveredPosition_WithWithdrawal_LastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController" or "owner".
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
        controller.supplyWRT = user.balanceWRT;

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "aggrievedUser" calls "withdrawRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.withdrawRecoveryTokens(amount);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT + openPosition - redeemable);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(wrappedRecoveryToken.totalSupply(), controller.supplyWRT - user.balanceWRT);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), 0);

        // And: "underlyingToken" balance of "owner" increases with redeemable.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT - redeemable);
    }

    function testFuzz_Pass_withdrawRecoveryTokens_FullyRecoveredPosition_WithWithdrawal_NotLastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController" or "owner".
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
        vm.assume(user.balanceWRT < type(uint256).max);
        controller.supplyWRT = bound(controller.supplyWRT, user.balanceWRT + 1, type(uint256).max);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "aggrievedUser" calls "withdrawRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.withdrawRecoveryTokens(amount);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT + openPosition - redeemable);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(wrappedRecoveryToken.totalSupply(), controller.supplyWRT - user.balanceWRT);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - redeemable);

        // And: "underlyingToken" balance of "owner" does not increase.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }

    function testFuzz_Pass_withdrawRecoveryTokens_FullyRecoveredPosition_WithoutWithdrawal_LastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-condition FullyRecoveredPosition).
        // Before even rTokens are withdrawn (test-condition WithoutWithdrawal).
        // -> "openPosition is smaller or equal to "redeemable".
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_withdrawRecoveryTokens_ZeroAmount).
        amount = bound(amount, 1, type(uint256).max);

        // And: "totalSupply" equals the balance of the user (test-condition LastPosition).
        controller.supplyWRT = user.balanceWRT;

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "aggrievedUser" calls "withdrawRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.withdrawRecoveryTokens(amount);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(wrappedRecoveryToken.totalSupply(), 0);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), 0);

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT - openPosition);
    }

    function testFuzz_Pass_withdrawRecoveryTokens_FullyRecoveredPosition_WithoutWithdrawal_NotLastPosition(
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController" or "owner".
        vm.assume(user.addr != address(recoveryControllerExtension));
        vm.assume(user.addr != address(users.owner));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is fully covered (test-condition FullyRecoveredPosition).
        // Before even rTokens are withdrawn (test-condition WithoutWithdrawal).
        // -> "openPosition is smaller or equal to "redeemable".
        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);
        vm.assume(openPosition <= redeemable);

        // And: Amount is strictly greater as zero (zero amount reverts see: testFuzz_Revert_withdrawRecoveryTokens_ZeroAmount).
        amount = bound(amount, 1, type(uint256).max);

        // And: "totalSupply" is strictly bigger as the balance of the user (test-condition NotLastPosition).
        vm.assume(user.balanceWRT < type(uint256).max);
        controller.supplyWRT = bound(controller.supplyWRT, user.balanceWRT + 1, type(uint256).max);

        // And: Assume "surplus" does not overflow (unrealistic big numbers).
        vm.assume(redeemable <= type(uint256).max - user.redeemed);
        uint256 surplus = user.redeemed + redeemable - user.balanceWRT;
        // And: Assume "delta" does not overflow (unrealistic big numbers).
        vm.assume(surplus <= type(uint256).max / 1e18);
        uint256 delta = surplus * 1e18 / (controller.supplyWRT - user.balanceWRT);
        // And: Assume "redeemablePerRTokenGlobal" does not overflow (unrealistic big numbers).
        vm.assume(controller.redeemablePerRTokenGlobal <= type(uint256).max - delta);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "aggrievedUser" calls "withdrawRecoveryTokens".
        vm.prank(user.addr);
        recoveryControllerExtension.withdrawRecoveryTokens(amount);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        assertEq(recoveryToken.balanceOf(user.addr), user.balanceRT);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(wrappedRecoveryToken.totalSupply(), controller.supplyWRT - user.balanceWRT);
        assertEq(recoveryControllerExtension.redeemablePerRTokenGlobal(), controller.redeemablePerRTokenGlobal + delta);
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryControllerExtension)), controller.balanceUT - openPosition);

        // And: "underlyingToken" balance of "owner" does not increase.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }
}
