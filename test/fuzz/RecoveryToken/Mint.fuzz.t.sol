/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryToken_Fuzz_Test} from "./_RecoveryToken.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "mint" of "RecoveryToken".
 */
contract Mint_RecoveryToken_Fuzz_Test is RecoveryToken_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryToken_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_mint_NonRecoveryController(address unprivilegedAddress, uint256 amount) public {
        // Given: Caller is not the "recoveryController".
        vm.assume(unprivilegedAddress != address(recoveryController));

        // When: Caller mints "amount".
        // Then: Transaction should revert with "NotRecoveryController".
        vm.prank(unprivilegedAddress);
        vm.expectRevert(NotRecoveryController.selector);
        recoveryTokenExtension.mint(amount);
    }

    function testFuzz_Success_mint(uint256 initialBalance, uint256 amount) public {
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
}
