/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";
import { UserState } from "../../utils/Types.sol";

/**
 * @notice Fuzz tests for the function "mintRecoveryTokens" of "RecoveryController".
 */
contract MintRecoveryTokens_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_mintRecoveryTokens_NonOwner(address unprivilegedAddress, address to, uint256 amount)
        public
    {
        // Given: Caller is not the "owner".
        vm.assume(unprivilegedAddress != users.owner);

        // When: "unprivilegedAddress" mintRecoveryTokens "amount" to "to".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        recoveryControllerExtension.mintRecoveryTokens(to, amount);
    }

    function testFuzz_Success_mintRecoveryTokens(address to, uint256 initialBalanceTo, uint256 amount) public {
        // And: Balance "to" does not overflow after mintRecoveryTokens of "amount".
        vm.assume(amount <= type(uint256).max - initialBalanceTo);
        // And: "to" has "initialBalanceTo" of "recoveryToken".
        deal(address(recoveryToken), to, initialBalanceTo);

        // When: "owner" mintRecoveryTokens "amount" to "to".
        vm.prank(users.owner);
        recoveryControllerExtension.mintRecoveryTokens(to, amount);

        // Then: "recoveryToken" balance of "to" should increase with "amount".
        assertEq(recoveryToken.balanceOf(to), initialBalanceTo + amount);
    }
}
