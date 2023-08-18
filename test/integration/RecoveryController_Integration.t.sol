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

    /*//////////////////////////////////////////////////////////////
                        RECOVERY TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_distributeUnderlying(uint256 redeemablePerRTokenGlobal, uint256 amount, uint256 totalSupply)
        public
    {
        // Given: totalSupply is non-zero.
        vm.assume(totalSupply > 0);
        // And: New redeemablePerRTokenGlobal does not overflow.
        amount = bound(amount, 0, type(uint256).max / 10e18);
        uint256 delta = amount * 10e18 / totalSupply;
        redeemablePerRTokenGlobal = bound(redeemablePerRTokenGlobal, 0, type(uint256).max - delta);
        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        stdstore.target(address(recoveryController)).sig(recoveryController.totalSupply.selector).checked_write(
            totalSupply
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
        uint256 balanceOf,
        uint256 redeemed
    ) public {
        // Given: "redeemablePerRTokenLast" is smaller or equal as "redeemablePerRTokenGlobal" (Invariant).
        redeemablePerRTokenLast = bound(redeemablePerRTokenLast, 0, redeemablePerRTokenGlobal);
        // And: "redeemable" does not overflow.
        if (redeemablePerRTokenLast != redeemablePerRTokenGlobal) {
            balanceOf = bound(balanceOf, 0, type(uint256).max / (redeemablePerRTokenGlobal - redeemablePerRTokenLast));
        }
        // And: "redeemed" is smaller or equal as "balanceOf" (Invariant).
        redeemed = bound(redeemed, 0, balanceOf);
        // And: The position is not fully covered.
        uint256 redeemable = balanceOf * (redeemablePerRTokenGlobal - redeemablePerRTokenLast) / 10e18;
        uint256 openPosition = balanceOf - redeemed;
        vm.assume(openPosition > redeemable);
        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        stdstore.target(address(recoveryController)).sig(recoveryController.balanceOf.selector).with_key(aggrievedUser)
            .checked_write(balanceOf);
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
        uint256 balanceOf,
        uint256 redeemed
    ) public {
        // Given: "redeemablePerRTokenLast" is smaller or equal as "redeemablePerRTokenGlobal" (Invariant).
        redeemablePerRTokenLast = bound(redeemablePerRTokenLast, 0, redeemablePerRTokenGlobal);
        // And: "redeemable" does not overflow.
        if (redeemablePerRTokenLast != redeemablePerRTokenGlobal) {
            balanceOf = bound(balanceOf, 0, type(uint256).max / (redeemablePerRTokenGlobal - redeemablePerRTokenLast));
        }
        // And: "redeemed" is smaller or equal as "balanceOf" (Invariant).
        redeemed = bound(redeemed, 0, balanceOf);
        // And: The position is fully covered.
        uint256 redeemable = balanceOf * (redeemablePerRTokenGlobal - redeemablePerRTokenLast) / 10e18;
        uint256 openPosition = balanceOf - redeemed;
        vm.assume(openPosition <= redeemable);
        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        stdstore.target(address(recoveryController)).sig(recoveryController.balanceOf.selector).with_key(aggrievedUser)
            .checked_write(balanceOf);
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
        uint256 totalSupply,
        uint256 redeemablePerRTokenGlobal
    ) public {
        // Given: totalSupply is non-zero.
        vm.assume(totalSupply > 0);
        // And: New redeemablePerRTokenGlobal does not overflow.
        amount = bound(amount, 0, type(uint256).max / 10e18);
        uint256 delta = amount * 10e18 / totalSupply;
        redeemablePerRTokenGlobal = bound(redeemablePerRTokenGlobal, 0, type(uint256).max - delta);
        // And: "redeemable" does not overflow.
        if (delta > 0) {
            vm.assume(totalSupply <= type(uint256).max / (redeemablePerRTokenGlobal + delta));
        }

        // Given: one "aggrievedUser" holds the total supply and has nothing redeemed.
        vm.prank(users.owner);
        recoveryController.mint(aggrievedUser, totalSupply);
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
        uint256 maxRoundingError = totalSupply / 10e18 + 1;
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
        address aggrievedUser,
        uint256 redeemablePerRTokenGlobal,
        uint256 redeemablePerRTokenLast,
        uint256 balanceOf,
        uint256 redeemed,
        uint256 initialRTokenController,
        uint256 initialUTokenController
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(aggrievedUser != address(recoveryController));

        // Given: "redeemablePerRTokenLast" is smaller or equal as "redeemablePerRTokenGlobal" (Invariant).
        redeemablePerRTokenLast = bound(redeemablePerRTokenLast, 0, redeemablePerRTokenGlobal);
        // And: "redeemable" does not overflow.
        if (redeemablePerRTokenLast != redeemablePerRTokenGlobal) {
            balanceOf = bound(balanceOf, 0, type(uint256).max / (redeemablePerRTokenGlobal - redeemablePerRTokenLast));
        }
        // And: "redeemed" is smaller or equal as "balanceOf" (Invariant).
        redeemed = bound(redeemed, 0, balanceOf);
        // And: The position is not fully covered.
        uint256 redeemable = balanceOf * (redeemablePerRTokenGlobal - redeemablePerRTokenLast) / 10e18;
        uint256 openPosition = balanceOf - redeemed;
        vm.assume(openPosition > redeemable);
        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        deal(address(wrappedRecoveryToken), aggrievedUser, balanceOf);
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemed.selector).with_key(aggrievedUser)
            .checked_write(redeemed);
        recoveryController.setRedeemablePerRTokenLast(aggrievedUser, redeemablePerRTokenLast);

        // Given: Balance "initialRTokenController" of "recoveryController" for "recoveryToken" is greater or equal as "openPosition" (Invariant).
        initialRTokenController = bound(initialRTokenController, openPosition, type(uint256).max);
        deal(address(recoveryToken), address(recoveryController), initialRTokenController);
        // And: Balance "initialUTokenController" of "recoveryController" for "underlyingToken" is greater or equal as "redeemable" (Invariant).
        initialUTokenController = bound(initialUTokenController, redeemable, type(uint256).max);
        deal(address(underlyingToken), address(recoveryController), initialUTokenController);

        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryController.activate();

        // When: "caller" calls "redeemUnderlying" for "aggrievedUser".
        vm.prank(caller);
        recoveryController.redeemUnderlying(aggrievedUser);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(recoveryController.redeemed(aggrievedUser), redeemed + redeemable);
        assertEq(recoveryController.getRedeemablePerRTokenLast(aggrievedUser), redeemablePerRTokenGlobal);
        // And: "recoveryToken" balance of "recoveryController" decreases with "redeemable".
        assertEq(recoveryToken.balanceOf(address(recoveryController)), initialRTokenController - redeemable);
        // And: "underlyingToken" balance of "recoveryController" decreases with "redeemable".
        assertEq(underlyingToken.balanceOf(address(recoveryController)), initialUTokenController - redeemable);
        // And: "underlyingToken" balance of "aggrievedUser" increases with "redeemable".
        assertEq(underlyingToken.balanceOf(aggrievedUser), redeemable);
    }

    function testFuzz_redeemUnderlying_FullyRecoveredPosition_LastPosition(
        address caller,
        address aggrievedUser,
        uint256 redeemablePerRTokenGlobal,
        uint256 redeemablePerRTokenLast,
        uint256 balanceOf,
        uint256 redeemed,
        uint256 initialRTokenController,
        uint256 initialUTokenController
    ) public {
        caller = address(0);
        aggrievedUser = address(0);
        redeemablePerRTokenGlobal = 0;
        redeemablePerRTokenLast = 0;
        balanceOf = 0;
        redeemed = 0;
        initialRTokenController = 10000;
        initialUTokenController = 10000;
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(aggrievedUser != address(recoveryController));

        // Given: "redeemablePerRTokenLast" is smaller or equal as "redeemablePerRTokenGlobal" (Invariant).
        redeemablePerRTokenLast = bound(redeemablePerRTokenLast, 0, redeemablePerRTokenGlobal);
        // And: "redeemable" does not overflow.
        if (redeemablePerRTokenLast != redeemablePerRTokenGlobal) {
            balanceOf = bound(balanceOf, 0, type(uint256).max / (redeemablePerRTokenGlobal - redeemablePerRTokenLast));
        }
        // And: "redeemed" is smaller as "balanceOf" (Invariant).
        redeemed = bound(redeemed, 0, balanceOf);
        // And: The position is not fully covered.
        uint256 redeemable = balanceOf * (redeemablePerRTokenGlobal - redeemablePerRTokenLast) / 10e18;
        uint256 openPosition = balanceOf - redeemed;
        vm.assume(openPosition <= redeemable);
        // And: "surplus_" does not overflow.
        if (redeemed > 0) vm.assume(redeemable <= type(uint256).max / redeemed);
        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        deal(address(wrappedRecoveryToken), aggrievedUser, balanceOf);
        stdstore.target(address(wrappedRecoveryToken)).sig(recoveryController.totalSupply.selector)
            .checked_write(balanceOf);
        emit log_named_uint("totalsupply1", wrappedRecoveryToken.totalSupply());
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemed.selector).with_key(aggrievedUser)
            .checked_write(redeemed);
        recoveryController.setRedeemablePerRTokenLast(aggrievedUser, redeemablePerRTokenLast);

        // Given: Balance "initialRTokenController" of "recoveryController" for "recoveryToken" is greater or equal as "openPosition" (Invariant).
        initialRTokenController = bound(initialRTokenController, openPosition, type(uint256).max);
        deal(address(recoveryToken), address(recoveryController), initialRTokenController);
        // And: Balance "initialUTokenController" of "recoveryController" for "underlyingToken" is greater or equal as "redeemable" (Invariant).
        initialUTokenController = bound(initialUTokenController, redeemable, type(uint256).max);
        deal(address(underlyingToken), address(recoveryController), initialUTokenController);

        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryController.activate();

        emit log_named_uint("totalsupply2", wrappedRecoveryToken.totalSupply());
        emit log_named_uint("openPosition", openPosition);
        emit log_named_uint("redeemable", redeemable);
        emit log_named_uint("balanceOf", balanceOf);
        emit log_named_uint("initialRTokenController", initialRTokenController);
        emit log_named_uint("initialUTokenController", initialUTokenController);
        // When: "caller" calls "redeemUnderlying" for "aggrievedUser".
        vm.prank(caller);
        recoveryController.redeemUnderlying(aggrievedUser);

        // Then: "aggrievedUser" position is closed.
        assertEq(wrappedRecoveryToken.balanceOf(aggrievedUser), 0);
        assertEq(recoveryController.redeemed(aggrievedUser), 0);
        assertEq(recoveryController.getRedeemablePerRTokenLast(aggrievedUser), 0);
        // And: "recoveryToken" balance of "recoveryController" decreases with "openPosition".
        assertEq(recoveryToken.balanceOf(address(recoveryController)), initialRTokenController - openPosition);
        // And: "underlyingToken" balance of "recoveryController" is zero.
        assertEq(underlyingToken.balanceOf(address(recoveryController)), 0);
        // And: "underlyingToken" balance of "aggrievedUser" increases with "openPosition".
        assertEq(underlyingToken.balanceOf(aggrievedUser), openPosition);
        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), initialUTokenController - openPosition);
    }

    function testFuzz_redeemUnderlying_FullyRecoveredPosition_NotLastPosition(
        address caller,
        address aggrievedUser,
        uint256 redeemablePerRTokenGlobal,
        uint256 redeemablePerRTokenLast,
        uint256 balanceOf,
        uint256 redeemed,
        uint256 initialRTokenController,
        uint256 initialUTokenController
    ) public {
        caller = address(0);
        aggrievedUser = address(0);
        redeemablePerRTokenGlobal = 1442371705343219403799901934176946609368877262062;
        redeemablePerRTokenLast = 59758143550363524431507393256326614911;
        balanceOf = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
        redeemed = 0;
        initialRTokenController = 1361129467683753853853498429727072845823;
        initialUTokenController = 115792089237316195423570985008687907853269984665640564039457584007913129639934;

        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(aggrievedUser != address(recoveryController));

        // ToDo: Properly avoid overflow due to _distributeUnderlying()
        redeemablePerRTokenGlobal = bound(redeemablePerRTokenGlobal, 0, type(uint256).max / 10e25);

        // Given: "redeemablePerRTokenLast" is smaller or equal as "redeemablePerRTokenGlobal" (Invariant).
        redeemablePerRTokenLast = bound(redeemablePerRTokenLast, 0, redeemablePerRTokenGlobal);
        // And: "redeemable" does not overflow.
        if (redeemablePerRTokenLast != redeemablePerRTokenGlobal) {
            balanceOf = bound(balanceOf, 0, type(uint256).max / (redeemablePerRTokenGlobal - redeemablePerRTokenLast));
        }
        // And: "redeemed" is smaller as "balanceOf" (Invariant).
        redeemed = bound(redeemed, 0, balanceOf);
        // And: The position is not fully covered.
        uint256 redeemable = balanceOf * (redeemablePerRTokenGlobal - redeemablePerRTokenLast) / 10e18;
        uint256 openPosition = balanceOf - redeemed;
        vm.assume(openPosition <= redeemable);
        // And: "surplus_" does not overflow.
        if (redeemed > 0) vm.assume(redeemable <= type(uint256).max / redeemed);
        // ToDo: And: _distributeUnderlying() does not overflow.
        uint256 surplus = 

        // Set variables.
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemablePerRTokenGlobal.selector)
            .checked_write(redeemablePerRTokenGlobal);
        deal(address(wrappedRecoveryToken), aggrievedUser, balanceOf);
        // totalSupply bigger as balanceOf.
        // ToDo: fuzz totalSupply.
        stdstore.target(address(wrappedRecoveryToken)).sig(recoveryController.totalSupply.selector)
            .checked_write(balanceOf + 1);
        emit log_named_uint("totalsupply1", wrappedRecoveryToken.totalSupply());
        stdstore.target(address(recoveryController)).sig(recoveryController.redeemed.selector).with_key(aggrievedUser)
            .checked_write(redeemed);
        recoveryController.setRedeemablePerRTokenLast(aggrievedUser, redeemablePerRTokenLast);

        // Given: Balance "initialRTokenController" of "recoveryController" for "recoveryToken" is greater or equal as "openPosition" (Invariant).
        initialRTokenController = bound(initialRTokenController, openPosition, type(uint256).max);
        deal(address(recoveryToken), address(recoveryController), initialRTokenController);
        // And: Balance "initialUTokenController" of "recoveryController" for "underlyingToken" is greater or equal as "redeemable" (Invariant).
        initialUTokenController = bound(initialUTokenController, redeemable, type(uint256).max);
        deal(address(underlyingToken), address(recoveryController), initialUTokenController);

        // Given: "RecoveryController" is active.
        vm.prank(users.owner);
        recoveryController.activate();

        emit log_named_uint("totalsupply2", wrappedRecoveryToken.totalSupply());
        emit log_named_uint("openPosition", openPosition);
        emit log_named_uint("redeemable", redeemable);
        emit log_named_uint("balanceOf", balanceOf);
        emit log_named_uint("initialRTokenController", initialRTokenController);
        emit log_named_uint("initialUTokenController", initialUTokenController);
        // When: "caller" calls "redeemUnderlying" for "aggrievedUser".
        vm.prank(caller);
        recoveryController.redeemUnderlying(aggrievedUser);

        // Then: "aggrievedUser" position is closed.
        assertEq(wrappedRecoveryToken.balanceOf(aggrievedUser), 0);
        assertEq(recoveryController.redeemed(aggrievedUser), 0);
        assertEq(recoveryController.getRedeemablePerRTokenLast(aggrievedUser), 0);
        // And: "recoveryToken" balance of "recoveryController" decreases with "openPosition".
        assertEq(recoveryToken.balanceOf(address(recoveryController)), initialRTokenController - openPosition);
        // And: "underlyingToken" balance of "recoveryController" decreases with "openPosition".
        assertEq(underlyingToken.balanceOf(address(recoveryController)), initialUTokenController - openPosition);
        // And: "underlyingToken" balance of "aggrievedUser" increases with "openPosition".
        assertEq(underlyingToken.balanceOf(aggrievedUser), openPosition);
        // And: "underlyingToken" balance of "owner" is zero.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }
}
