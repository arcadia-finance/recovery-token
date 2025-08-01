/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";
import { UserState } from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the function "batchBurn" of "RecoveryController".
 */
contract BatchBurn_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_batchBurn_NonOwner(
        address unprivilegedAddress,
        address[2] calldata froms,
        uint256[2] calldata amounts
    ) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory froms_ = castArrayStaticToDynamic(froms);
        uint256[] memory amounts_ = castArrayStaticToDynamic(amounts);

        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" burns "amount" from "froms".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.batchBurn(froms_, amounts_);
    }

    function testFuzz_Revert_batchBurn_Active(address[2] calldata froms, uint256[2] calldata amounts) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory froms_ = castArrayStaticToDynamic(froms);
        uint256[] memory amounts_ = castArrayStaticToDynamic(amounts);

        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryControllerExtension.activate();

        // When: "owner" burns "amount" from "from".
        // Then: Transaction should revert with "Active".
        vm.prank(users.owner);
        vm.expectRevert(Active.selector);
        recoveryControllerExtension.batchBurn(froms_, amounts_);
    }

    function testFuzz_Revert_batchBurn_LengthMismatch(address[2] calldata froms, uint256[] calldata amounts) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory froms_ = castArrayStaticToDynamic(froms);

        // Given: "RecoveryController" is not active.

        // And: Length of both input arrays is not equal (test-condition LengthMismatch).
        vm.assume(froms.length != amounts.length);

        // When: "owner" burns "amounts" from "froms".
        // Then: Transaction should revert with "LengthMismatch".
        vm.prank(users.owner);
        vm.expectRevert(LengthMismatch.selector);
        recoveryControllerExtension.batchBurn(froms_, amounts);
    }

    function testFuzz_Success_batchBurn_PositionPartiallyClosed(
        address[2] calldata froms,
        uint256[2] calldata initialBalanceFroms,
        uint256[2] calldata amounts,
        uint256 controllerBalanceRT
    ) public {
        address[] memory froms_ = castArrayStaticToDynamic(froms);
        uint256[] memory initialBalanceFroms_ = castArrayStaticToDynamic(initialBalanceFroms);
        uint256[] memory amounts_ = castArrayStaticToDynamic(amounts);
        vm.assume(uniqueAddresses(froms_));

        // Cache variables.
        uint256 length = froms_.length;
        uint256 totalAmount;
        uint256 totalOpenPosition;

        // Given: Each "amounts[i]" is strictly smaller as "initialBalanceFroms[i]" (test-condition PositionPartiallyClosed).
        // -> Each "initialBalanceFroms[i]" is also at least 1.
        for (uint256 i; i < length; ++i) {
            initialBalanceFroms_[i] = bound(initialBalanceFroms_[i], 1, type(uint256).max);
            amounts_[i] = bound(amounts_[i], 0, initialBalanceFroms_[i] - 1);

            // totalOpenPosition can't be higher as type(uint256).max.
            vm.assume(initialBalanceFroms_[i] <= type(uint256).max - totalOpenPosition);
            totalOpenPosition += initialBalanceFroms_[i];
            totalAmount += amounts_[i];
        }

        // And: Total "openPosition" is smaller or equal to "initialBalanceController" (Invariant!).
        controllerBalanceRT = bound(controllerBalanceRT, totalOpenPosition, type(uint256).max);

        // And: State is persisted.
        vm.prank(users.owner);
        recoveryControllerExtension.batchMint(froms_, initialBalanceFroms_);

        deal(address(recoveryToken), address(recoveryControllerExtension), controllerBalanceRT);

        // When: "owner" burns "amounts" from "froms".
        vm.prank(users.owner);
        recoveryControllerExtension.batchBurn(froms_, amounts_);

        // Then: "wrappedRecoveryToken" balance of each "froms[i]" should decrease with "amounts[i]".
        for (uint256 i; i < froms_.length; ++i) {
            assertEq(wrappedRecoveryToken.balanceOf(froms_[i]), initialBalanceFroms_[i] - amounts_[i]);
        }
        // And: "recoveryToken" balance of "recoveryController" should decrease with sum of all "amounts".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controllerBalanceRT - totalAmount);
    }

    function testFuzz_Success_batchBurn_PositionFullyClosed(
        address[2] calldata froms,
        uint256[2] calldata initialBalanceFroms,
        uint256[2] calldata amounts,
        uint256 controllerBalanceRT
    ) public {
        address[] memory froms_ = castArrayStaticToDynamic(froms);
        uint256[] memory initialBalanceFroms_ = castArrayStaticToDynamic(initialBalanceFroms);
        uint256[] memory amounts_ = castArrayStaticToDynamic(amounts);
        vm.assume(uniqueAddresses(froms_));

        // Cache variables.
        uint256 length = froms_.length;
        uint256 totalOpenPosition;

        // Given: Each "amounts[i]" is greater or equal as "initialBalanceFroms[i]" (test-condition PositionPartiallyClosed).
        for (uint256 i; i < length; ++i) {
            amounts_[i] = bound(amounts_[i], initialBalanceFroms_[i], type(uint256).max);

            // totalOpenPosition can't be higher as type(uint256).max.
            vm.assume(initialBalanceFroms_[i] <= type(uint256).max - totalOpenPosition);
            totalOpenPosition += initialBalanceFroms_[i];
        }

        // And: Total "openPosition" is smaller or equal to "initialBalanceController" (Invariant!).
        controllerBalanceRT = bound(controllerBalanceRT, totalOpenPosition, type(uint256).max);

        // And: State is persisted.
        vm.prank(users.owner);
        recoveryControllerExtension.batchMint(froms_, initialBalanceFroms_);
        deal(address(recoveryToken), address(recoveryControllerExtension), controllerBalanceRT);

        // When: "owner" burns "amounts" from "froms".
        vm.prank(users.owner);
        recoveryControllerExtension.batchBurn(froms_, amounts_);

        // Then: "wrappedRecoveryToken" balance of each "froms[i]" should be 0.
        for (uint256 i; i < froms_.length; ++i) {
            assertEq(wrappedRecoveryToken.balanceOf(froms_[i]), 0);
        }
        // And: "recoveryToken" balance of "recoveryController" should decrease with sum of all "openPosition".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controllerBalanceRT - totalOpenPosition);
    }
}
