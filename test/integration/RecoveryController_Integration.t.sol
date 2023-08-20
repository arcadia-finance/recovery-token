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

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Integration_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    struct UserState {
        address addr;
        uint256 redeemed;
        uint256 redeemablePerRTokenLast;
        uint256 balanceWRT;
        uint256 balanceRT;
        uint256 balanceUT;
    }

    struct ControllerState {
        bool active;
        uint256 redeemablePerRTokenGlobal;
        uint256 supplyWRT;
        uint256 balanceRT;
        uint256 balanceUT;
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
        user.balanceUT =
            bound(user.balanceUT, 0, type(uint256).max - (redeemable < openPosition ? redeemable : openPosition));

        // Invariant: Balance "controllerBalanceRT" of "recoveryController" for "recoveryToken" is greater or equal as "openPosition".
        controller.balanceRT = bound(controller.balanceRT, openPosition, type(uint256).max);

        // Invariant: Balance "controllerBalanceUT" of "recoveryController" for "underlyingToken" is greater or equal as "redeemable".
        controller.balanceUT = bound(controller.balanceUT, redeemable, type(uint256).max);

        return (user, controller);
    }

    function setUserState(UserState memory user) public {
        // Set redeemed tokens.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemed.selector).with_key(user.addr)
            .checked_write(user.redeemed);

        // Set redeemablePerRTokenLast of last interaction user.
        recoveryController.setRedeemablePerRTokenLast(user.addr, user.redeemablePerRTokenLast);

        // Set token balances.
        deal(address(wrappedRecoveryToken), user.addr, user.balanceWRT);
        deal(address(recoveryToken), user.addr, user.balanceRT);
        deal(address(underlyingToken), user.addr, user.balanceUT);
    }

    function setControllerState(ControllerState memory controller) public {
        // Set activation.
        recoveryController.setActive(controller.active);

        // Set latest "redeemablePerRTokenGlobal".
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(controller.redeemablePerRTokenGlobal);

        // Set "totalSupply" of "wrappedRecoveryToken"
        stdstore.target(address(wrappedRecoveryToken)).sig(wrappedRecoveryToken.totalSupply.selector).checked_write(
            controller.supplyWRT
        );

        // Set token balances.
        deal(address(recoveryToken), address(recoveryController), controller.balanceRT);
        deal(address(underlyingToken), address(recoveryController), controller.balanceUT);
    }

    function calculateRedeemableAndOpenAmount(UserState memory user, ControllerState memory controller)
        public
        pure
        returns (uint256 redeemable, uint256 openPosition)
    {
        redeemable = user.balanceWRT * (controller.redeemablePerRTokenGlobal - user.redeemablePerRTokenLast) / 10e18;
        openPosition = user.balanceWRT - user.redeemed;
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
                        ACTIVATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_activate_(address unprivilegedAddress) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" calls "activate".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryController.activate();
    }

    function test_activate() public {
        // Given:
        // When: "unprivilegedAddress" calls "activate".
        vm.prank(users.owner);
        recoveryController.activate();

        // Then "RecoveryController" is active.
        assertTrue(recoveryController.active());
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
        vm.assume(uniqueAddresses(froms_));

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

    /*//////////////////////////////////////////////////////////////
                        RECOVERY TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_distributeUnderlying(uint256 redeemablePerRTokenGlobal, uint256 amount, uint256 supplyWRT)
        public
    {
        // Given: supplyWRT is non-zero.
        vm.assume(supplyWRT > 0);
        // And: New redeemablePerRTokenGlobal does not overflow.
        amount = bound(amount, 0, type(uint256).max / 10e18);
        uint256 delta = amount * 10e18 / supplyWRT;
        redeemablePerRTokenGlobal = bound(redeemablePerRTokenGlobal, 0, type(uint256).max - delta);
        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        stdstore.target(address(recoveryController)).sig(recoveryController.totalSupply.selector).checked_write(
            supplyWRT
        );

        // When: "amount" of "underlyingToken" is distributed.
        recoveryController.distributeUnderlying(amount);

        // Then: "redeemablePerRTokenGlobal" is increased with "delta".
        assertEq(recoveryController.redeemablePerRTokenGlobal(), redeemablePerRTokenGlobal + delta);
    }

    function testFuzz_maxRedeemable_NonRecoveredPosition(
        address aggrievedUser,
        uint256 redeemablePerRTokenGlobal,
        uint256 redeemablePerRTokenLast,
        uint256 userBalanceWRT,
        uint256 redeemed
    ) public {
        // Given: "redeemablePerRTokenLast" is smaller or equal as "redeemablePerRTokenGlobal" (Invariant).
        redeemablePerRTokenLast = bound(redeemablePerRTokenLast, 0, redeemablePerRTokenGlobal);
        // And: "redeemable" does not overflow.
        if (redeemablePerRTokenLast != redeemablePerRTokenGlobal) {
            userBalanceWRT =
                bound(userBalanceWRT, 0, type(uint256).max / (redeemablePerRTokenGlobal - redeemablePerRTokenLast));
        }
        // And: "redeemed" is smaller or equal as "userBalanceWRT" (Invariant).
        redeemed = bound(redeemed, 0, userBalanceWRT);
        // And: The position is not fully covered.
        uint256 redeemable = userBalanceWRT * (redeemablePerRTokenGlobal - redeemablePerRTokenLast) / 10e18;
        uint256 openPosition = userBalanceWRT - redeemed;
        vm.assume(openPosition > redeemable);
        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        stdstore.target(address(recoveryController)).sig(recoveryController.balanceOf.selector).with_key(aggrievedUser)
            .checked_write(userBalanceWRT);
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemed.selector).with_key(aggrievedUser)
            .checked_write(redeemed);
        recoveryController.setRedeemablePerRTokenLast(aggrievedUser, redeemablePerRTokenLast);

        // When: "maxRedeemable" is called for "aggrievedUser".
        uint256 maxRedeemable = recoveryController.maxRedeemable(aggrievedUser);

        // Then: Transaction returns "redeemable".
        assertEq(maxRedeemable, redeemable);
    }

    function testFuzz_maxRedeemable_FullyRecoveredPosition(
        address aggrievedUser,
        uint256 redeemablePerRTokenGlobal,
        uint256 redeemablePerRTokenLast,
        uint256 userBalanceWRT,
        uint256 redeemed
    ) public {
        // Given: "redeemablePerRTokenLast" is smaller or equal as "redeemablePerRTokenGlobal" (Invariant).
        redeemablePerRTokenLast = bound(redeemablePerRTokenLast, 0, redeemablePerRTokenGlobal);
        // And: "redeemable" does not overflow.
        if (redeemablePerRTokenLast != redeemablePerRTokenGlobal) {
            userBalanceWRT =
                bound(userBalanceWRT, 0, type(uint256).max / (redeemablePerRTokenGlobal - redeemablePerRTokenLast));
        }
        // And: "redeemed" is smaller or equal as "userBalanceWRT" (Invariant).
        redeemed = bound(redeemed, 0, userBalanceWRT);
        // And: The position is fully covered.
        uint256 redeemable = userBalanceWRT * (redeemablePerRTokenGlobal - redeemablePerRTokenLast) / 10e18;
        uint256 openPosition = userBalanceWRT - redeemed;
        vm.assume(openPosition <= redeemable);
        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        stdstore.target(address(recoveryController)).sig(recoveryController.balanceOf.selector).with_key(aggrievedUser)
            .checked_write(userBalanceWRT);
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemed.selector).with_key(aggrievedUser)
            .checked_write(redeemed);
        recoveryController.setRedeemablePerRTokenLast(aggrievedUser, redeemablePerRTokenLast);

        // When: "maxRedeemable" is called for "aggrievedUser".
        uint256 maxRedeemable = recoveryController.maxRedeemable(aggrievedUser);

        // Then: Transaction returns "openPosition".
        assertEq(maxRedeemable, openPosition);
    }

    function testFuzz_Revert_depositUnderlying_NotActive(address caller, uint256 amount) public {
        // Given: "RecoveryController" is not active.

        // When: "caller" calls "redeemUnderlying".
        // Then: Transaction should revert with "NOT_ACTIVE".
        vm.prank(caller);
        vm.expectRevert("NOT_ACTIVE");
        recoveryController.depositUnderlying(amount);
    }

    function testFuzz_depositUnderlying(
        address depositor,
        address aggrievedUser,
        uint256 amount,
        uint256 supplyWRT,
        uint256 redeemablePerRTokenGlobal
    ) public {
        // Given: supplyWRT is non-zero.
        vm.assume(supplyWRT > 0);
        // And: New redeemablePerRTokenGlobal does not overflow.
        amount = bound(amount, 0, type(uint256).max / 10e18);
        uint256 delta = amount * 10e18 / supplyWRT;
        redeemablePerRTokenGlobal = bound(redeemablePerRTokenGlobal, 0, type(uint256).max - delta);
        // And: "redeemable" does not overflow.
        if (delta > 0) {
            vm.assume(supplyWRT <= type(uint256).max / (redeemablePerRTokenGlobal + delta));
        }

        // Given: one "aggrievedUser" holds the total supply and has nothing redeemed.
        vm.prank(users.owner);
        recoveryController.mint(aggrievedUser, supplyWRT);
        // Set state variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        recoveryController.setRedeemablePerRTokenLast(aggrievedUser, redeemablePerRTokenGlobal);

        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryController.activate();

        // When: A "depositor" deposits "amount" of "underlyingToken".
        deal(address(underlyingToken), depositor, amount);
        vm.startPrank(depositor);
        underlyingToken.approve(address(recoveryController), amount);
        recoveryController.depositUnderlying(amount);
        vm.stopPrank();

        // Then: Balance of "underlyingToken" is increased with "amount".
        assertEq(underlyingToken.balanceOf(address(recoveryController)), amount);

        // And: The "amount" is redeemable by "aggrievedUser".
        uint256 redeemable = recoveryController.previewRedeemable(aggrievedUser);
        uint256 maxRoundingError = supplyWRT / 10e18 + 1;
        uint256 lowerBound = maxRoundingError < amount ? amount - maxRoundingError : 0;
        assertLe(lowerBound, redeemable);
        assertLe(redeemable, amount);
    }

    function testFuzz_Revert_redeemUnderlying_NotActive(address caller, address aggrievedUser) public {
        // Given: "RecoveryController" is not active.

        // When: "caller" calls "redeemUnderlying".
        // Then: Transaction should revert with "NOT_ACTIVE".
        vm.prank(caller);
        vm.expectRevert("NOT_ACTIVE");
        recoveryController.redeemUnderlying(aggrievedUser);
    }

    function testFuzz_redeemUnderlying_NonRecoveredPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryController));

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: The position is not fully covered (test-condition NonRecoveredPosition).
        uint256 redeemable =
            user.balanceWRT * (controller.redeemablePerRTokenGlobal - user.redeemablePerRTokenLast) / 10e18;
        uint256 openPosition = user.balanceWRT - user.redeemed;
        vm.assume(openPosition > redeemable);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "caller" calls "redeemUnderlying" for "aggrievedUser".
        vm.prank(caller);
        recoveryController.redeemUnderlying(user.addr);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(recoveryController.redeemed(user.addr), user.redeemed + redeemable);
        assertEq(recoveryController.getRedeemablePerRTokenLast(user.addr), controller.redeemablePerRTokenGlobal);
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + redeemable);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryController)), controller.balanceRT - redeemable);
        assertEq(underlyingToken.balanceOf(address(recoveryController)), controller.balanceUT - redeemable);
    }

    function testFuzz_redeemUnderlying_FullyRecoveredPosition_LastPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryController));

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
        recoveryController.redeemUnderlying(user.addr);

        // Then: "aggrievedUser" position is closed.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryController.redeemed(user.addr), 0);
        assertEq(recoveryController.getRedeemablePerRTokenLast(user.addr), 0);
        // And: "aggrievedUser" token balances are updated.
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryController)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryController)), 0);

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), controller.balanceUT - openPosition);
    }

    function testFuzz_redeemUnderlying_FullyRecoveredPosition_NotLastPosition(
        address caller,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryController));

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
        vm.assume(surplus <= type(uint256).max / 10e18);
        uint256 delta = surplus * 10e18 / (controller.supplyWRT - user.balanceWRT);
        // And: Assume "redeemablePerRTokenGlobal" does not overflow (unrealistic big numbers).
        vm.assume(controller.redeemablePerRTokenGlobal <= type(uint256).max - delta);

        // And: State is persisted.
        setUserState(user);
        setControllerState(controller);

        // When: "caller" calls "redeemUnderlying" for "aggrievedUser".
        vm.prank(caller);
        recoveryController.redeemUnderlying(user.addr);

        // Then: "aggrievedUser" position is closed.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryController.redeemed(user.addr), 0);
        assertEq(recoveryController.getRedeemablePerRTokenLast(user.addr), 0);
        // And: "aggrievedUser" token balances are updated.
        assertEq(underlyingToken.balanceOf(user.addr), user.balanceUT + openPosition);

        // And: "controller" state variables are updated.
        assertEq(recoveryToken.balanceOf(address(recoveryController)), controller.balanceRT - openPosition);
        assertEq(underlyingToken.balanceOf(address(recoveryController)), controller.balanceUT - openPosition);

        // And: "underlyingToken" balance of "owner" is zero.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }
}
