/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { ControllerState, UserState } from "../../utils/Types.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { Fuzz_Test } from "../Fuzz.t.sol";
import { RecoveryControllerExtension } from "../../utils/Extensions.sol";
import { RecoveryToken } from "../../../src/RecoveryToken.sol";
import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";

/**
 * @notice Common logic needed by all "RecoveryController" fuzz tests.
 */
abstract contract RecoveryController_Fuzz_Test is Fuzz_Test {
    using stdStorage for StdStorage;

    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    RecoveryControllerExtension internal recoveryControllerExtension;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Fuzz_Test.setUp();

        // Deploy Recovery contracts.
        vm.prank(users.creator);
        recoveryControllerExtension = new RecoveryControllerExtension(address(underlyingToken));
        recoveryToken = RecoveryToken(recoveryControllerExtension.RECOVERY_TOKEN());
        wrappedRecoveryToken = ERC20(address(recoveryControllerExtension));

        // Label the contracts.
        vm.label({ account: address(recoveryToken), newLabel: "RecoveryToken" });
        vm.label({ account: address(recoveryControllerExtension), newLabel: "RecoveryController" });
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function givenValidDepositAmount(
        uint256 amount,
        uint256 minAmount,
        uint256 maxAmount,
        UserState memory user,
        ControllerState memory controller
    ) public view returns (uint256) {
        // And: "amount" is smaller or equal as "user.balanceRT" (underflow, see testFuzz_Revert_depositRecoveryTokens_InsufficientBalance).
        vm.assume(user.balanceRT >= minAmount);
        amount = bound(amount, minAmount, user.balanceRT);
        // And: "amount" does not overflow "totalSupply" (unrealistic big values).
        vm.assume(controller.supplyWRT <= type(uint256).max - minAmount);
        amount = bound(amount, minAmount, type(uint256).max - controller.supplyWRT);
        // And: "amount" does not overflow "controller.balanceRT" (unrealistic big values).
        vm.assume(controller.balanceRT <= type(uint256).max - minAmount);
        amount = bound(amount, minAmount, type(uint256).max - controller.balanceRT);
        // And: "amount" is smaller or equal as "maxAmount"
        amount = bound(amount, minAmount, maxAmount);

        return amount;
    }

    function givenValidActiveState(UserState memory user, ControllerState memory controller)
        public
        view
        returns (UserState memory, ControllerState memory)
    {
        // Test-Case: Active
        controller.active = true;

        // Invariant: "redeemablePerRTokenLast" is smaller or equal as "redeemablePerRTokenGlobal" (Invariant).
        user.redeemablePerRTokenLast = bound(user.redeemablePerRTokenLast, 0, controller.redeemablePerRTokenGlobal);
        // Overflow: "redeemable" does not overflow (unrealistic big variables).
        if (user.redeemablePerRTokenLast != controller.redeemablePerRTokenGlobal) {
            user.balanceWRT = bound(
                user.balanceWRT,
                0,
                type(uint256).max / (controller.redeemablePerRTokenGlobal - user.redeemablePerRTokenLast)
            );
        }
        // Invariant: "redeemed" is smaller or equal as "userBalanceWRT".
        user.redeemed = bound(user.redeemed, 0, user.balanceWRT);

        (uint256 redeemable, uint256 openPosition) = calculateRedeemableAndOpenAmount(user, controller);

        // Overflow: balance of "user" for "underlyingToken" after redemption (unrealistic big variables).
        user.balanceUT = bound(user.balanceUT, 0, type(uint256).max - redeemable);
        user.balanceUT = bound(user.balanceUT, 0, type(uint256).max - openPosition);

        // Invariant: "recoveryToken" balance of the "controller" is greater or equal as "openPosition" of any user.
        controller.balanceRT = bound(controller.balanceRT, openPosition, type(uint256).max);

        // Invariant: "underlyingToken" balance of the "controller" is greater or equal as "redeemable" of any user.
        controller.balanceUT = bound(controller.balanceUT, redeemable, type(uint256).max);

        // Invariant ERC20: no "wrappedRecoveryToken" balance can exceed its totalSupply.
        controller.supplyWRT = bound(controller.supplyWRT, user.balanceWRT, type(uint256).max);

        // Invariant: Sum of the balances of "wrappedRecoveryToken" and "recoveryToken" for a single user,
        // can never exceed initial totalSupply "wrappedRecoveryToken" -> Sum can never exceed type(uint256).max.
        user.balanceRT = bound(user.balanceRT, 0, type(uint256).max - user.balanceWRT);

        return (user, controller);
    }

    function setUserState(UserState memory user) public {
        // Set redeemed tokens.
        stdstore.target(address(recoveryControllerExtension)).sig(recoveryControllerExtension.redeemed.selector)
            .with_key(user.addr).checked_write(user.redeemed);

        // Set redeemablePerRTokenLast of last interaction user.
        recoveryControllerExtension.setRedeemablePerRTokenLast(user.addr, user.redeemablePerRTokenLast);

        // Set token balances.
        deal(address(wrappedRecoveryToken), user.addr, user.balanceWRT);
        deal(address(recoveryToken), user.addr, user.balanceRT);
        deal(address(underlyingToken), user.addr, user.balanceUT);
    }

    function setControllerState(ControllerState memory controller) public {
        // Set activation.
        recoveryControllerExtension.setActive(controller.active);

        // Set latest "redeemablePerRTokenGlobal".
        stdstore.target(address(recoveryControllerExtension)).sig(
            recoveryControllerExtension.redeemablePerRTokenGlobal.selector
        ).checked_write(controller.redeemablePerRTokenGlobal);

        // Set "totalSupply" of "wrappedRecoveryToken"
        stdstore.target(address(wrappedRecoveryToken)).sig(wrappedRecoveryToken.totalSupply.selector).checked_write(
            controller.supplyWRT
        );

        // Set token balances.
        deal(address(recoveryToken), address(recoveryControllerExtension), controller.balanceRT);
        deal(address(underlyingToken), address(recoveryControllerExtension), controller.balanceUT);
    }

    function calculateRedeemableAndOpenAmount(UserState memory user, ControllerState memory controller)
        public
        pure
        returns (uint256 redeemable, uint256 openPosition)
    {
        redeemable = user.balanceWRT * (controller.redeemablePerRTokenGlobal - user.redeemablePerRTokenLast) / 1e18;
        openPosition = user.balanceWRT - user.redeemed;
    }
}
