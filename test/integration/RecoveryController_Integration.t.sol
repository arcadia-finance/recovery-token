/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {StdStorage, stdStorage} from "../../lib/forge-std/src/Test.sol";
import {stdError} from "../../lib/forge-std/src/StdError.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {UserState, ControllerState} from "../utils/Types.sol";
import {Integration_Test} from "./Integration.t.sol";
import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {RecoveryToken} from "../../src/RecoveryToken.sol";
import {RecoveryControllerExtension} from "../utils/Extensions.sol";

contract RecoveryController_Integration_Test is Integration_Test {
    using stdStorage for StdStorage;
    using FixedPointMathLib for uint256;
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
        Integration_Test.setUp();

        // Deploy Recovery contracts.
        vm.prank(users.creator);
        recoveryControllerExtension = new RecoveryControllerExtension(address(underlyingToken));
        recoveryToken = RecoveryToken(recoveryControllerExtension.recoveryToken());
        wrappedRecoveryToken = ERC20(address(recoveryControllerExtension));

        // Label the contracts.
        vm.label({account: address(recoveryToken), newLabel: "RecoveryToken"});
        vm.label({account: address(recoveryControllerExtension), newLabel: "RecoveryController"});
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

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
        redeemable = user.balanceWRT * (controller.redeemablePerRTokenGlobal - user.redeemablePerRTokenLast) / 10e18;
        openPosition = user.balanceWRT - user.redeemed;
    }

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

    /* ///////////////////////////////////////////////////////////////
                            DEPLOYMENT
    /////////////////////////////////////////////////////////////// */

    function testFuzz_deployment(address owner_) public {
        // Given:

        // When "owner_" deploys "recoveryController_".
        vm.prank(owner_);
        vm.expectEmit();
        emit ActiveSet(false);
        RecoveryControllerExtension recoveryController_ = new RecoveryControllerExtension(address(underlyingToken));

        // Then: the immutable variables are set on "recoveryController_".
        assertEq(recoveryController_.owner(), owner_);
        assertEq(recoveryController_.getUnderlying(), address(underlyingToken));
        assertEq(recoveryController_.decimals(), underlyingToken.decimals());
    }

    /*//////////////////////////////////////////////////////////////
                        ACTIVATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_activate(address unprivilegedAddress) public {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" calls "activate".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.activate();
    }

    function test_activate() public {
        // Given:
        // When: "unprivilegedAddress" calls "activate".
        vm.prank(users.owner);
        vm.expectEmit(address(recoveryControllerExtension));
        emit ActiveSet(true);
        recoveryControllerExtension.activate();

        // Then "RecoveryController" is active.
        assertTrue(recoveryControllerExtension.active());
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_transfer(address aggrievedUser, address to, uint256 initialBalance, uint256 amount)
        public
    {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryControllerExtension), aggrievedUser, initialBalance);

        // When: "aggrievedUser" transfers "amount" to "to".
        // Then: Transaction should revert with "NoTransfersAllowed".
        vm.prank(aggrievedUser);
        vm.expectRevert(NoTransfersAllowed.selector);
        recoveryControllerExtension.transfer(to, amount);
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
        deal(address(recoveryControllerExtension), aggrievedUser, initialBalance);
        // And: "caller" has allowance of "allowance" from "aggrievedUser"
        vm.prank(aggrievedUser);
        recoveryControllerExtension.approve(caller, allowance);

        // When: "caller" transfers "amount" from "aggrievedUser" to "to".
        // Then: Transaction should revert with "NoTransfersAllowed".
        vm.prank(caller);
        vm.expectRevert(NoTransfersAllowed.selector);
        recoveryControllerExtension.transferFrom(aggrievedUser, to, amount);
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
        address[] memory tos_ = castArrayFixedToDynamic(tos);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);

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
        address[] memory tos_ = castArrayFixedToDynamic(tos);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);

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
        address[] memory tos_ = castArrayFixedToDynamic(tos);

        // Given: "RecoveryController" is not active.

        // And: Length of both input arrays is not equal (test-condition LengthMismatch).
        vm.assume(tos.length != amounts.length);

        // When: "owner" mints "amounts" to "tos".
        // Then: Transaction should revert with "LengthMismatch".
        vm.prank(users.owner);
        vm.expectRevert(LengthMismatch.selector);
        recoveryControllerExtension.batchMint(tos_, amounts);
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

    function testFuzz_Revert_batchBurn_LengthMismatch(address[2] calldata froms, uint256[] calldata amounts) public {
        // Cast between fixed size arrays and dynamic size array.
        address[] memory froms_ = castArrayFixedToDynamic(froms);

        // Given: "RecoveryController" is not active.

        // And: Length of both input arrays is not equal (test-condition LengthMismatch).
        vm.assume(froms.length != amounts.length);

        // When: "owner" burns "amounts" from "froms".
        // Then: Transaction should revert with "LengthMismatch".
        vm.prank(users.owner);
        vm.expectRevert(LengthMismatch.selector);
        recoveryControllerExtension.batchBurn(froms_, amounts);
    }

    function testFuzz_burn_PositionPartiallyClosed(UserState memory user, uint256 amount, uint256 controllerBalanceRT)
        public
    {
        // Given: "amount" is strictly smaller as "openPosition" (test-condition PositionPartiallyClosed).
        // -> userBalanceWRT is also at least 1.
        user.balanceWRT = bound(user.balanceWRT, 1, type(uint256).max);
        user.redeemed = bound(user.redeemed, 0, user.balanceWRT - 1); // Invariant.
        uint256 openPosition = user.balanceWRT - user.redeemed;
        amount = bound(amount, 0, openPosition - 1);

        // And: "openPosition" is smaller or equal to "initialBalanceController" (Invariant!).
        controllerBalanceRT = bound(controllerBalanceRT, openPosition, type(uint256).max);

        // And: State is persisted.
        setUserState(user);
        deal(address(recoveryToken), address(recoveryControllerExtension), controllerBalanceRT);

        // When: "owner" burns "amount" from "from".
        vm.prank(users.owner);
        recoveryControllerExtension.burn(user.addr, amount);

        // Then: "wrappedRecoveryToken" balance of "user" should decrease with "amount".
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), user.balanceWRT - amount);
        // And: "recoveryToken" balance of "recoveryController" should decrease with "amount".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controllerBalanceRT - amount);
    }

    function testFuzz_burn_PositionFullyClosed(UserState memory user, uint256 amount, uint256 controllerBalanceRT)
        public
    {
        // Given: "amount" is greater or equal as "openPosition" (test-condition PositionPartiallyClosed).
        user.redeemed = bound(user.redeemed, 0, user.balanceWRT); // Invariant.
        uint256 openPosition = user.balanceWRT - user.redeemed;
        amount = bound(amount, openPosition, type(uint256).max);

        // And: "openPosition" is smaller or equal to "initialBalanceController" (Invariant!).
        controllerBalanceRT = bound(controllerBalanceRT, openPosition, type(uint256).max);

        // And: State is persisted.
        setUserState(user);
        deal(address(recoveryToken), address(recoveryControllerExtension), controllerBalanceRT);

        // When: "owner" burns "amount" from "from".
        vm.prank(users.owner);
        recoveryControllerExtension.burn(user.addr, amount);

        // Then: "aggrievedUser" state variables are updated.
        assertEq(wrappedRecoveryToken.balanceOf(user.addr), 0);
        assertEq(recoveryControllerExtension.redeemed(user.addr), 0);
        assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(user.addr), 0);
        // And: "recoveryToken" balance of "recoveryController" should decrease with "openPosition".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controllerBalanceRT - openPosition);
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
        recoveryControllerExtension.batchBurn(froms_, amounts_);
    }

    function testFuzz_batchBurn_PositionPartiallyClosed(
        UserState[2] calldata froms,
        uint256[2] calldata amounts,
        uint256 controllerBalanceRT
    ) public {
        UserState[] memory froms_ = castArrayFixedToDynamicUserState(froms);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);
        vm.assume(uniqueUsers(froms_));

        // Cache variables.
        uint256 length = froms_.length;
        uint256 totalAmount;
        uint256 totalOpenPosition;
        address[] memory fromAddrs = new address[](length);

        // Given: Each "amounts[i]" is strictly smaller as "openPosition[i]" (test-condition PositionPartiallyClosed).
        // -> Each userBalanceWRT is also at least 1.
        for (uint256 i; i < length; ++i) {
            fromAddrs[i] = froms_[i].addr;

            froms_[i].balanceWRT = bound(froms_[i].balanceWRT, 1, type(uint256).max);
            froms_[i].redeemed = bound(froms_[i].redeemed, 0, froms_[i].balanceWRT - 1); // Invariant.
            uint256 openPosition = froms_[i].balanceWRT - froms_[i].redeemed;
            amounts_[i] = bound(amounts_[i], 0, openPosition - 1);

            // totalOpenPosition can't be higher as type(uint256).max.
            vm.assume(froms_[i].balanceWRT <= type(uint256).max - totalOpenPosition);
            totalOpenPosition += openPosition;
            totalAmount += amounts_[i];
        }

        // And: Total "openPosition" is smaller or equal to "initialBalanceController" (Invariant!).
        controllerBalanceRT = bound(controllerBalanceRT, totalOpenPosition, type(uint256).max);

        // And: State is persisted.
        for (uint256 i; i < length; ++i) {
            setUserState(froms_[i]);
        }
        deal(address(recoveryToken), address(recoveryControllerExtension), controllerBalanceRT);

        // When: "owner" burns "amounts" from "froms".
        vm.prank(users.owner);
        recoveryControllerExtension.batchBurn(fromAddrs, amounts_);

        // Then: "wrappedRecoveryToken" balance of each "froms[i]" should decrease with "amounts[i]".
        for (uint256 i; i < froms_.length; ++i) {
            assertEq(wrappedRecoveryToken.balanceOf(froms_[i].addr), froms_[i].balanceWRT - amounts_[i]);
        }
        // And: "recoveryToken" balance of "recoveryController" should decrease with sum of all "amounts".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controllerBalanceRT - totalAmount);
    }

    function testFuzz_batchBurn_PositionFullyClosed(
        UserState[2] calldata froms,
        uint256[2] calldata amounts,
        uint256 controllerBalanceRT
    ) public {
        UserState[] memory froms_ = castArrayFixedToDynamicUserState(froms);
        uint256[] memory amounts_ = castArrayFixedToDynamic(amounts);
        vm.assume(uniqueUsers(froms_));

        // Cache variables.
        uint256 length = froms_.length;
        uint256 totalOpenPosition;
        address[] memory fromAddrs = new address[](length);

        // Given: Each "amounts[i]" is greater or equal as "openPosition[i]" (test-condition PositionPartiallyClosed).
        // -> Each userBalanceWRT is also at least 1.
        for (uint256 i; i < length; ++i) {
            fromAddrs[i] = froms_[i].addr;

            froms_[i].balanceWRT = bound(froms_[i].balanceWRT, 1, type(uint256).max);
            froms_[i].redeemed = bound(froms_[i].redeemed, 0, froms_[i].balanceWRT - 1); // Invariant.
            uint256 openPosition = froms_[i].balanceWRT - froms_[i].redeemed;
            amounts_[i] = bound(amounts_[i], openPosition, type(uint256).max);

            // totalOpenPosition can't be higher as type(uint256).max.
            vm.assume(froms_[i].balanceWRT <= type(uint256).max - totalOpenPosition);
            totalOpenPosition += openPosition;
        }

        // And: Total "openPosition" is smaller or equal to "initialBalanceController" (Invariant!).
        controllerBalanceRT = bound(controllerBalanceRT, totalOpenPosition, type(uint256).max);

        // And: State is persisted.
        for (uint256 i; i < length; ++i) {
            setUserState(froms_[i]);
        }
        deal(address(recoveryToken), address(recoveryControllerExtension), controllerBalanceRT);

        // When: "owner" burns "amounts" from "froms".
        vm.prank(users.owner);
        recoveryControllerExtension.batchBurn(fromAddrs, amounts_);

        // Then: "wrappedRecoveryToken" balance of each "froms[i]" should decrease with "amounts[i]".
        for (uint256 i; i < froms_.length; ++i) {
            assertEq(wrappedRecoveryToken.balanceOf(froms_[i].addr), 0);
            assertEq(recoveryControllerExtension.redeemed(froms_[i].addr), 0);
            assertEq(recoveryControllerExtension.getRedeemablePerRTokenLast(froms_[i].addr), 0);
        }
        // And: "recoveryToken" balance of "recoveryController" should decrease with sum of all "openPosition".
        assertEq(recoveryToken.balanceOf(address(recoveryControllerExtension)), controllerBalanceRT - totalOpenPosition);
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

    function testFuzz_depositUnderlying(
        address depositor,
        uint256 amount,
        UserState memory user,
        ControllerState memory controller
    ) public {
        // Given: "aggrievedUser" is not the "recoveryController".
        vm.assume(user.addr != address(recoveryControllerExtension));

        // And: "amount" is non-zero.
        vm.assume(amount > 0);

        // And: "depositor" is not "aggrievedUser" or "recoveryController".
        vm.assume(depositor != address(recoveryControllerExtension));
        vm.assume(depositor != user.addr);

        // And: The protocol is active with a random valid state.
        (user, controller) = givenValidActiveState(user, controller);

        // And: "controller.supplyWRT" is non-zero.
        vm.assume(controller.supplyWRT > 0);

        // And: Balance "controller.supplyUT" does not overflow (ERC20 Invariant).
        vm.assume(controller.balanceUT < type(uint256).max);
        amount = bound(amount, 1, type(uint256).max - controller.balanceUT);

        // And: Assume "delta" does not overflow (unrealistic big numbers).
        amount = bound(amount, 1, type(uint256).max / 10e18);
        uint256 delta = amount * 10e18 / controller.supplyWRT;
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
        uint256 lowerBoundTotal;
        {
            // No direct function on the contract -> calculate actualTotalRedeemable of last deposit.
            uint256 actualTotalRedeemable = recoveryControllerExtension.totalSupply()
                * (recoveryControllerExtension.redeemablePerRTokenGlobal() - controller.redeemablePerRTokenGlobal) / 10e18;
            uint256 maxRoundingError = controller.supplyWRT / 10e18 + 1;
            // Lower bound of the error.
            lowerBoundTotal = maxRoundingError < amount ? amount - maxRoundingError : 0;
            // Upper bound is the amount deposited itself.
            uint256 upperBoundTotal = amount;
            assertLe(lowerBoundTotal, actualTotalRedeemable);
            assertLe(actualTotalRedeemable, upperBoundTotal);
        }

        // And: A proportional share of "amount" is redeemable by "aggrievedUser".
        uint256 actualUserRedeemable = recoveryControllerExtension.previewRedeemable(user.addr) - userRedeemableLast;
        // ToDo: use Full Math library proper MulDiv.
        if (user.balanceWRT != 0) vm.assume(amount <= type(uint256).max / user.balanceWRT);
        uint256 lowerBoundUser = lowerBoundTotal.mulDivDown(user.balanceWRT, controller.supplyWRT);
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

    function testFuzz_maxRedeemable_NonRecoveredPosition(UserState memory user, ControllerState memory controller)
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

    function testFuzz_maxRedeemable_FullyRecoveredPosition(UserState memory user, ControllerState memory controller)
        public
    {
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

    function testFuzz_redeemUnderlying_NonRecoveredPosition(
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

    function testFuzz_redeemUnderlying_FullyRecoveredPosition_LastPosition(
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

    function testFuzz_redeemUnderlying_FullyRecoveredPosition_NotLastPosition(
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
        vm.assume(surplus <= type(uint256).max / 10e18);
        uint256 delta = surplus * 10e18 / (controller.supplyWRT - user.balanceWRT);
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

    function testFuzz_depositRecoveryTokens_NoInitialPosition(
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

    function testFuzz_depositRecoveryTokens_WithInitialPosition_NonRecoveredPosition(
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

    function testFuzz_depositRecoveryTokens_WithInitialPosition_FullyRecoveredPosition_LastPosition(
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

    function testFuzz_depositRecoveryTokens_WithInitialPosition_FullyRecoveredPosition_NotLastPosition(
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
        vm.assume(surplus <= type(uint256).max / 10e18);
        uint256 delta = surplus * 10e18 / (controller.supplyWRT - user.balanceWRT);
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

    function testFuzz_withdrawRecoveryTokens_NonRecoveredPosition(
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

    function testFuzz_withdrawRecoveryTokens_FullyRecoveredPosition_WithWithdrawal_LastPosition(
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

    function testFuzz_withdrawRecoveryTokens_FullyRecoveredPosition_WithWithdrawal_NotLastPosition(
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

    function testFuzz_withdrawRecoveryTokens_FullyRecoveredPosition_WithoutWithdrawal_LastPosition(
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

    function testFuzz_withdrawRecoveryTokens_FullyRecoveredPosition_WithoutWithdrawal_NotLastPosition(
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
        vm.assume(surplus <= type(uint256).max / 10e18);
        uint256 delta = surplus * 10e18 / (controller.supplyWRT - user.balanceWRT);
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

        // And: "underlyingToken" balance of "owner" increases with remaining funds.
        assertEq(underlyingToken.balanceOf(users.owner), 0);
    }
}
