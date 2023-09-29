/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "./_RecoveryController.fuzz.t.sol";

import {UserState} from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the function "burn" of "RecoveryController".
 */
contract Burn_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_burn_NonOwner(address unprivilegedAddress, address from, uint256 amount) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" burns "amount" from "from".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.burn(from, amount);
    }

    function testFuzz_Revert_burn_Active(address from, uint256 amount) public {
        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryControllerExtension.activate();

        // When: "owner" burns "amount" from "from".
        // Then: Transaction should revert with "Active".
        vm.prank(users.owner);
        vm.expectRevert(Active.selector);
        recoveryControllerExtension.burn(from, amount);
    }

    function testFuzz_Success_burn_PositionPartiallyClosed(
        address from,
        uint256 initialBalanceFrom,
        uint256 amount,
        uint256 controllerBalanceRT
    ) public {
        // Given: "amount" is strictly smaller as "initialBalanceFrom" (test-condition PositionPartiallyClosed).
        // -> "initialBalanceFrom" is also at least 1.
        initialBalanceFrom = bound(initialBalanceFrom, 1, type(uint256).max);
        amount = bound(amount, 0, initialBalanceFrom - 1);

        // And: "initialBalanceFrom" is smaller or equal to "initialBalanceController" (Invariant!).
        controllerBalanceRT = bound(controllerBalanceRT, initialBalanceFrom, type(uint256).max);

        // And: State is persisted.
        vm.prank(users.owner);
        recoveryControllerExtension.mint(from, initialBalanceFrom);
        deal(address(recoveryToken), address(recoveryControllerExtension), controllerBalanceRT);

        // When: "owner" burns "amount" from "from".
        vm.prank(users.owner);
        recoveryControllerExtension.burn(from, amount);

        // Then: "wrappedRecoveryToken" balance of "user" should decrease with "amount".
        assertEq(wrappedRecoveryToken.balanceOf(from), initialBalanceFrom - amount);
        // And: "recoveryToken" balance of "recoveryController" should decrease with "amount".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controllerBalanceRT - amount);
    }

    function testFuzz_Success_burn_PositionFullyClosed(
        address from,
        uint256 initialBalanceFrom,
        uint256 amount,
        uint256 controllerBalanceRT
    ) public {
        // Given: "amount" is greater or equal as "initialBalanceFrom" (test-condition PositionPartiallyClosed).
        amount = bound(amount, initialBalanceFrom, type(uint256).max);

        // And: "initialBalanceFrom" is smaller or equal to "initialBalanceController" (Invariant!).
        controllerBalanceRT = bound(controllerBalanceRT, initialBalanceFrom, type(uint256).max);

        // And: State is persisted.
        vm.prank(users.owner);
        recoveryControllerExtension.mint(from, initialBalanceFrom);
        deal(address(recoveryToken), address(recoveryControllerExtension), controllerBalanceRT);

        // When: "owner" burns "amount" from "from".
        vm.prank(users.owner);
        recoveryControllerExtension.burn(from, amount);

        // Then: "user" state variables are updated.
        assertEq(wrappedRecoveryToken.balanceOf(from), 0);
        // And: "recoveryToken" balance of "recoveryController" should decrease with "initialBalanceFrom".
        assertEq(
            recoveryToken.balanceOf(address(recoveryControllerExtension)), controllerBalanceRT - initialBalanceFrom
        );
    }
}
