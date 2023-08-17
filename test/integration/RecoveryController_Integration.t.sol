/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {StdStorage, stdStorage} from "../../lib/forge-std/src/Test.sol";
import {Integration_Test} from "./Integration.t.sol";
import {RecoveryControllerExtension} from "../utils/Extensions.sol";

contract RecoveryController_Integration_Test is Integration_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                    MODIFIERS GIVEN STATEMENTS
    /////////////////////////////////////////////////////////////// */

    modifier givenCallerIs(address caller) {
        vm.startPrank(caller);
        _;
        vm.stopPrank();
    }

    modifier givenRecoveryControllerIsActive() {
        vm.prank(users.owner);
        recoveryController.activate();
        _;
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Integration_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                            DEPLOYMENT
    /////////////////////////////////////////////////////////////// */

    function testFuzz_deployment(address owner_) public {
        // Given:

        // When "owner_" deploys "recoveryController_".
        vm.prank(owner_);
        RecoveryControllerExtension recoveryController_ = new RecoveryControllerExtension(address(underlyingToken));

        // Then: the immutable variables are set on "recoveryController_".
        assertEq(recoveryController_.owner(), owner_);
        assertEq(recoveryController_.getUnderlying(), address(underlyingToken));
        assertEq(recoveryController_.decimals(), underlyingToken.decimals());
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_transfer(address aggrievedUser, address to, uint256 initialBalance, uint256 amount)
        public
    {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryController), aggrievedUser, initialBalance);

        // When: "aggrievedUser" transfers "amount" to "to".
        // Then: Transaction should revert with "arithmeticError".
        vm.prank(aggrievedUser);
        vm.expectRevert(NotAllowed.selector);
        recoveryController.transfer(to, amount);
    }

    function testFuzz_Revert_transferFrom(
        address caller,
        address aggrievedUser,
        address to,
        uint256 allowance,
        uint256 initialBalance,
        uint256 amount
    ) public {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryController), aggrievedUser, initialBalance);
        // And: "caller" has allowance of "allowance" from "aggrievedUser"
        vm.prank(aggrievedUser);
        recoveryController.approve(caller, allowance);

        // When: "caller" transfers "amount" from "aggrievedUser" to "to".
        // Then: Transaction should revert with "arithmeticError".
        vm.prank(caller);
        vm.expectRevert(NotAllowed.selector);
        recoveryController.transferFrom(aggrievedUser, to, amount);
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
        recoveryController.mint(to, amount);
    }

    function testFuzz_Revert_mint_Active(address to, uint256 amount) public {
        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryController.activate();

        // When: "owner" mints "amount" to "to".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(users.owner);
        vm.expectRevert("ACTIVE");
        recoveryController.mint(to, amount);
    }

    function testFuzz_mint(address to, uint256 initialBalanceTo, uint256 initialBalanceController, uint256 amount)
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
        deal(address(recoveryToken), address(recoveryController), initialBalanceController);

        // When: "owner" mints "amount" to "to".
        vm.prank(users.owner);
        recoveryController.mint(to, amount);

        // Then: "wrappedRecoveryToken" balance of "to" should increase with "amount".
        assertEq(wrappedRecoveryToken.balanceOf(to), initialBalanceTo + amount);
        // And: "recoveryToken" balance of "recoveryController" should increase with "amount".
        assertEq(recoveryToken.balanceOf(address(recoveryController)), initialBalanceController + amount);
    }

    function testFuzz_Revert_batchMint_NonOwner(
        address unprivilegedAddress,
        address[2] calldata tos,
        uint256[2] calldata amounts
    ) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory tos_ = castArrayFixedToDynamic(tos);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);

        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" mints "amount" to "to".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryController.batchMint(tos_, amounts_);
    }

    function testFuzz_Revert_batchMint_Active(address[2] calldata tos, uint256[2] calldata amounts) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory tos_ = castArrayFixedToDynamic(tos);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);

        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryController.activate();

        // When: "owner" mints "amount" to "to".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(users.owner);
        vm.expectRevert("ACTIVE");
        recoveryController.batchMint(tos_, amounts_);
    }

    function testFuzz_batchMint(
        address[2] calldata tos,
        uint256[2] calldata initialBalanceTos,
        uint256 initialBalanceController,
        uint256[2] calldata amounts
    ) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory tos_ = castArrayFixedToDynamic(tos);
        uint256[] memory initialBalanceTos_ = castArrayFixedToDynamic(initialBalanceTos);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);

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
        deal(address(recoveryToken), address(recoveryController), initialBalanceController);

        // When: "owner" mints "amounts" to "tos".
        vm.prank(users.owner);
        recoveryController.batchMint(tos_, amounts_);

        // Then: "wrappedRecoveryToken" balance of each "tos[i]" should increase with "amounts[i]".
        for (uint256 i; i < tos_.length; ++i) {
            assertEq(wrappedRecoveryToken.balanceOf(tos_[i]), initialBalanceTos_[i] + amounts_[i]);
        }
        // And: "recoveryToken" balance of "recoveryController" should increase with sum of all "amounts".
        assertEq(recoveryToken.balanceOf(address(recoveryController)), expectedBalanceController);
    }

    function testFuzz_Revert_burn_NonOwner(address unprivilegedAddress, address from, uint256 amount) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" burns "amount" from "from".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryController.burn(from, amount);
    }

    function testFuzz_burn(address from, uint256 initialBalanceFrom, uint256 initialBalanceController, uint256 amount)
        public
    {
        // Given: "RecoveryController" is not active.
        // And: "amount" is smaller or equal to "initialBalanceFrom".
        vm.assume(amount <= initialBalanceFrom);
        // And: "initialBalanceFrom" is smaller or equal to "initialBalanceController" (Invariant!).
        vm.assume(initialBalanceFrom <= initialBalanceController);
        // And: "from" has "initialBalanceFrom" of "wrappedRecoveryToken".
        deal(address(wrappedRecoveryToken), from, initialBalanceFrom);
        // And: "recoveryController" has "initialBalanceController" of "recoveryToken".
        deal(address(recoveryToken), address(recoveryController), initialBalanceController);

        // When: "owner" burns "amount" from "from".
        vm.prank(users.owner);
        recoveryController.burn(from, amount);

        // Then: "wrappedRecoveryToken" balance of "from" should decrease with "amount".
        assertEq(wrappedRecoveryToken.balanceOf(from), initialBalanceFrom - amount);
        // And: "recoveryToken" balance of "recoveryController" should decrease with "amount".
        assertEq(recoveryToken.balanceOf(address(recoveryController)), initialBalanceController - amount);
    }

    function testFuzz_Revert_batchBurn_NonOwner(
        address unprivilegedAddress,
        address[2] calldata froms,
        uint256[2] calldata amounts
    ) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory froms_ = castArrayFixedToDynamic(froms);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);

        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" burns "amount" from "froms".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryController.batchBurn(froms_, amounts_);
    }

    function testFuzz_batchBurn(
        address[2] calldata froms,
        uint256[2] calldata initialBalanceFroms,
        uint256 initialBalanceController,
        uint256[2] calldata amounts
    ) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory froms_ = castArrayFixedToDynamic(froms);
        uint256[] memory initialBalanceFroms_ = castArrayFixedToDynamic(initialBalanceFroms);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);

        // Given: "RecoveryController" is not active.
        // And: Each "amounts[i]" is smaller or equal to "initialBalanceFroms[i]".
        uint256 totalAmount;
        uint256 totalInitialBalanceFrom;
        for (uint256 i; i < froms_.length; ++i) {
            vm.assume(amounts[i] <= initialBalanceFroms_[i]);
            // totalInitialBalanceFrom can't be higher as type(uint256).max.
            vm.assume(initialBalanceFroms_[i] <= type(uint256).max - totalInitialBalanceFrom);
            totalInitialBalanceFrom += initialBalanceFroms_[i];
            totalAmount += amounts[i];
        }
        // And: Total "initialBalanceFroms" is smaller or equal to "initialBalanceController" (Invariant!).
        vm.assume(totalInitialBalanceFrom <= initialBalanceController);
        // And: "froms" have "initialBalanceFroms" of "wrappedRecoveryToken".
        for (uint256 i; i < froms_.length; ++i) {
            deal(address(wrappedRecoveryToken), froms_[i], initialBalanceFroms_[i]);
        }
        // And: "recoveryController" has "initialBalanceController" of "recoveryToken".
        deal(address(recoveryToken), address(recoveryController), initialBalanceController);

        // When: "owner" burns "amounts" from "froms".
        vm.prank(users.owner);
        recoveryController.batchBurn(froms_, amounts_);

        // Then: "wrappedRecoveryToken" balance of each "froms[i]" should decrease with "amounts[i]".
        for (uint256 i; i < froms_.length; ++i) {
            assertEq(wrappedRecoveryToken.balanceOf(froms_[i]), initialBalanceFroms_[i] - amounts_[i]);
        }
        // And: "recoveryToken" balance of "recoveryController" should decrease with sum of all "amounts".
        assertEq(recoveryToken.balanceOf(address(recoveryController)), initialBalanceController - totalAmount);
    }
}
