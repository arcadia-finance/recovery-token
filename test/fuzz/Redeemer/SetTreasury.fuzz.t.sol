/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Redeemer } from "../../../src/Redeemer.sol";
import { Redeemer_Fuzz_Test } from "./_Redeemer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setTreasury" of contract "Redeemer".
 */
contract SetTreasury_Redeemer_Fuzz_Test is Redeemer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Redeemer_Fuzz_Test.setUp();
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
        redeemer.setTreasury(newTreasury);
    }

    function testFuzz_Success_SetMerkleRoot(address newTreasury) public {
        // Given: Caller is the "owner".
        // When: Caller calls "setTreasury".
        // Then: correct event is emitted.
        vm.prank(users.owner);
        vm.expectEmit(address(redeemer));
        emit Redeemer.TreasurySet(newTreasury);
        redeemer.setTreasury(newTreasury);

        // And: New merkle root is set.
        assertEq(redeemer.treasury(), newTreasury);
    }
}
