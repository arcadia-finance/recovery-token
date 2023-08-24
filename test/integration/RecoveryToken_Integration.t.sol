/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {StdStorage, stdStorage} from "../../lib/forge-std/src/Test.sol";
import {stdError} from "../../lib/forge-std/src/StdError.sol";
import {Integration_Test} from "./Integration.t.sol";
import {RecoveryTokenExtension} from "../utils/Extensions.sol";

contract RecoveryToken_Integration_Test is Integration_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    RecoveryTokenExtension internal recoveryTokenExtension;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Integration_Test.setUp();

        // Deploy Recovery Token contract.
        recoveryTokenExtension =
            new RecoveryTokenExtension(users.creator, address(recoveryController), underlyingToken.decimals());

        // Label the contract.
        vm.label({account: address(recoveryToken), newLabel: "RecoveryToken"});
    }

    /* ///////////////////////////////////////////////////////////////
                            DEPLOYMENT
    /////////////////////////////////////////////////////////////// */

    function testFuzz_deployment(address owner_, address recoveryController_, uint8 decimals_) public {
        recoveryTokenExtension = new RecoveryTokenExtension(owner_, recoveryController_, decimals_);

        assertEq(recoveryTokenExtension.owner(), owner_);
        assertEq(recoveryTokenExtension.getRecoveryController(), recoveryController_);
        assertEq(recoveryTokenExtension.decimals(), decimals_);
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function testRevert_Fuzz_mint_NonRecoveryController(address unprivilegedAddress, uint256 amount) public {
        // Given: Caller is not the "recoveryController".
        vm.assume(unprivilegedAddress != address(recoveryController));

        // When: Caller mints "amount".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryTokenExtension.mint(amount);
    }

    function testFuzz_mint(uint256 initialBalance, uint256 amount) public {
        // Given "recoveryController" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), address(recoveryController), initialBalance);
        // And: Balance does not overflow after mint.
        vm.assume(amount <= type(uint256).max - initialBalance);

        // When: "recoveryController" mints "amount".
        vm.prank(address(recoveryController));
        recoveryTokenExtension.mint(amount);

        // Then: Balance of "recoveryController" should increase with "amount".
        assertEq(recoveryTokenExtension.balanceOf(address(recoveryController)), initialBalance + amount);
    }

    function testFuzz_Revert_burn_1arg_InsufficientBalance(
        address aggrievedUser,
        uint256 initialBalance,
        uint256 amount
    ) public {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), aggrievedUser, initialBalance);
        // And: "amount" is bigger as "initialBalance".
        vm.assume(amount > initialBalance);

        // When: "aggrievedUser" burns "amount".
        // Then: Transaction should revert with "arithmeticError".
        vm.prank(aggrievedUser);
        vm.expectRevert(stdError.arithmeticError);
        recoveryTokenExtension.burn(amount);
    }

    function testFuzz_burn_1arg(address aggrievedUser, uint256 initialBalance, uint256 amount) public {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), aggrievedUser, initialBalance);
        // And: "amount" is smaller or equal as "initialBalance".
        vm.assume(amount <= initialBalance);

        // When: "aggrievedUser" burns "amount".
        vm.prank(aggrievedUser);
        recoveryTokenExtension.burn(amount);

        // Then: Balance of "aggrievedUser" should decrease with "amount".
        assertEq(recoveryTokenExtension.balanceOf(aggrievedUser), initialBalance - amount);
    }

    function testFuzz_Revert_burn_2arg_NonRecoveryController(
        address unprivilegedAddress,
        address aggrievedUser,
        uint256 initialBalance,
        uint256 amount
    ) public {
        // Given: Caller is not the "recoveryController".
        vm.assume(unprivilegedAddress != address(recoveryController));
        // And: "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), aggrievedUser, initialBalance);

        // When: "unprivilegedAddress" burns "amount" of "aggrievedUser".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryTokenExtension.burn(aggrievedUser, amount);
    }

    function testFuzz_Revert_burn_2arg_InsufficientBalance(
        address aggrievedUser,
        uint256 initialBalance,
        uint256 amount
    ) public {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), aggrievedUser, initialBalance);
        // And: "amount" is bigger as "initialBalance".
        vm.assume(amount > initialBalance);

        // When: "recoveryController" burns "amount" of "aggrievedUser".
        // Then: Transaction should revert with "arithmeticError".
        vm.prank(address(recoveryController));
        vm.expectRevert(stdError.arithmeticError);
        recoveryTokenExtension.burn(aggrievedUser, amount);
    }

    function testFuzz_burn_2arg(address aggrievedUser, uint256 initialBalance, uint256 amount) public {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryTokenExtension), aggrievedUser, initialBalance);
        // And: "amount" is smaller or equal as "initialBalance".
        vm.assume(amount <= initialBalance);

        // When: "recoveryController" burns "amount" of "aggrievedUser".
        vm.prank(address(recoveryController));
        recoveryTokenExtension.burn(aggrievedUser, amount);

        // Then: Balance of "aggrievedUser" should decrease with "amount".
        assertEq(recoveryTokenExtension.balanceOf(aggrievedUser), initialBalance - amount);
    }
}
