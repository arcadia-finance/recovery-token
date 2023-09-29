/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "../RecoveryController.fuzz.t.sol";

import {UserState} from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the mint and burn logic of "RecoveryController".
 */
contract MintAndBurnLogic_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_mint_NonOwner(address unprivilegedAddress, address to, uint256 amount) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" mints "amount" to "to".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.mint(to, amount);
    }

    function testFuzz_Revert_mint_Active(address to, uint256 amount) public {
        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryControllerExtension.activate();

        // When: "owner" mints "amount" to "to".
        // Then: Transaction should revert with "Active".
        vm.prank(users.owner);
        vm.expectRevert(Active.selector);
        recoveryControllerExtension.mint(to, amount);
    }

    function testFuzz_Pass_mint(address to, uint256 initialBalanceTo, uint256 initialBalanceController, uint256 amount)
        public
    {
        // Given: "RecoveryController" is not active.
        // And: Balance "recoveryController" does not overflow after mint of "amount".
        vm.assume(amount <= type(uint256).max - initialBalanceController);
        // And: Balance "to" does not overflow after mint of "amount".
        vm.assume(amount <= type(uint256).max - initialBalanceTo);
        // And: "to" has "initialBalanceTo" of "wrappedRecoveryToken".
        deal(address(wrappedRecoveryToken), to, initialBalanceTo);
        // And: "recoveryController" has "initialBalanceController" of "recoveryToken".
        deal(address(recoveryToken), address(recoveryControllerExtension), initialBalanceController);

        // When: "owner" mints "amount" to "to".
        vm.prank(users.owner);
        recoveryControllerExtension.mint(to, amount);

        // Then: "wrappedRecoveryToken" balance of "to" should increase with "amount".
        assertEq(wrappedRecoveryToken.balanceOf(to), initialBalanceTo + amount);
        // And: "recoveryToken" balance of "recoveryController" should increase with "amount".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), initialBalanceController + amount);
    }

    function testFuzz_Revert_batchMint_NonOwner(
        address unprivilegedAddress,
        address[2] calldata tos,
        uint256[2] calldata amounts
    ) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory tos_ = castArrayStaticToDynamic(tos);
        uint256[] memory amounts_ = castArrayStaticToDynamic(amounts);

        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" mints "amount" to "to".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.batchMint(tos_, amounts_);
    }

    function testFuzz_Revert_batchMint_Active(address[2] calldata tos, uint256[2] calldata amounts) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory tos_ = castArrayStaticToDynamic(tos);
        uint256[] memory amounts_ = castArrayStaticToDynamic(amounts);

        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryControllerExtension.activate();

        // When: "owner" mints "amount" to "to".
        // Then: Transaction should revert with "Active".
        vm.prank(users.owner);
        vm.expectRevert(Active.selector);
        recoveryControllerExtension.batchMint(tos_, amounts_);
    }

    function testFuzz_Revert_batchMint_LengthMismatch(address[2] calldata tos, uint256[] calldata amounts) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory tos_ = castArrayStaticToDynamic(tos);

        // Given: "RecoveryController" is not active.

        // And: Length of both input arrays is not equal (test-condition LengthMismatch).
        vm.assume(tos.length != amounts.length);

        // When: "owner" mints "amounts" to "tos".
        // Then: Transaction should revert with "LengthMismatch".
        vm.prank(users.owner);
        vm.expectRevert(LengthMismatch.selector);
        recoveryControllerExtension.batchMint(tos_, amounts);
    }

    function testFuzz_Pass_batchMint(
        address[2] calldata tos,
        uint256[2] calldata initialBalanceTos,
        uint256 initialBalanceController,
        uint256[2] calldata amounts
    ) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory tos_ = castArrayStaticToDynamic(tos);
        uint256[] memory initialBalanceTos_ = castArrayStaticToDynamic(initialBalanceTos);
        uint256[] memory amounts_ = castArrayStaticToDynamic(amounts);
        vm.assume(uniqueAddresses(tos_));

        // Given: "RecoveryController" is not active.
        // And: Balances do not overflow after mint.
        uint256 expectedBalanceController = initialBalanceController;
        for (uint256 i; i < tos_.length; ++i) {
            vm.assume(amounts[i] <= type(uint256).max - expectedBalanceController);
            vm.assume(amounts[i] <= type(uint256).max - initialBalanceTos[i]);
            expectedBalanceController += amounts[i];
        }
        // And: "tos" have "initialBalanceTos" of "wrappedRecoveryToken".
        for (uint256 i; i < tos_.length; ++i) {
            deal(address(wrappedRecoveryToken), tos_[i], initialBalanceTos[i]);
        }
        // And: "recoveryController" has "initialBalanceController" of "recoveryToken".
        deal(address(recoveryToken), address(recoveryControllerExtension), initialBalanceController);

        // When: "owner" mints "amounts" to "tos".
        vm.prank(users.owner);
        recoveryControllerExtension.batchMint(tos_, amounts_);

        // Then: "wrappedRecoveryToken" balance of each "tos[i]" should increase with "amounts[i]".
        for (uint256 i; i < tos_.length; ++i) {
            assertEq(wrappedRecoveryToken.balanceOf(tos_[i]), initialBalanceTos_[i] + amounts_[i]);
        }
        // And: "recoveryToken" balance of "recoveryController" should increase with sum of all "amounts".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), expectedBalanceController);
    }

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

    function testFuzz_Pass_burn_PositionPartiallyClosed(
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

    function testFuzz_Pass_burn_PositionFullyClosed(
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

    function testFuzz_Pass_batchBurn_PositionPartiallyClosed(
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

    function testFuzz_Pass_batchBurn_PositionFullyClosed(
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
