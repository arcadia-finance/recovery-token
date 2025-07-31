/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { FeeClaimer } from "../../../src/FeeClaimer.sol";
import { FeeClaimer_Fuzz_Test } from "./_FeeClaimer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setTreasury" of contract "FeeClaimer".
 */
contract SetTreasury_FeeClaimer_Fuzz_Test is FeeClaimer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        FeeClaimer_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_SetMerkleRoot_OnlyOwner(address caller, address newTreasury) public {
        // Given: Caller is not the "owner".
        vm.assume(caller != users.owner);

        // When: Caller calls "setTreasury".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(caller);
        vm.expectRevert("UNAUTHORIZED");
        feeClaimer.setTreasury(newTreasury);
    }

    function testFuzz_Success_SetMerkleRoot(address newTreasury) public {
        // Given: Caller is the "owner".
        // When: Caller calls "setTreasury".
        // Then: correct event is emitted.
        vm.prank(users.owner);
        vm.expectEmit(address(feeClaimer));
        emit FeeClaimer.TreasurySet(newTreasury);
        feeClaimer.setTreasury(newTreasury);

        // And: New merkle root is set.
        assertEq(feeClaimer.treasury(), newTreasury);
    }
}
