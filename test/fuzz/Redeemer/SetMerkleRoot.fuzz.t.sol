/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Redeemer } from "../../../src/Redeemer.sol";
import { Redeemer_Fuzz_Test } from "./_Redeemer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setMerkleRoot" of contract "Redeemer".
 */
contract SetMerkleRoot_Redeemer_Fuzz_Test is Redeemer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Redeemer_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMerkleRoot_OnlyOwner(address caller, bytes32 newMerkleRoot) public {
        // Given: Caller is not the "owner".
        vm.assume(caller != users.owner);

        // When: Caller calls "setMerkleRoot".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(caller);
        vm.expectRevert("UNAUTHORIZED");
        redeemer.setMerkleRoot(newMerkleRoot);
    }

    function testFuzz_Revert_setMerkleRoot_InvalidRoot(bytes32 newMerkleRoot) public {
        // Given: Root is already set.
        vm.prank(users.owner);
        redeemer.setMerkleRoot(newMerkleRoot);

        // When: Caller calls "setMerkleRoot".
        // Then: Transaction should revert with "UNAUTHORIZED".
        vm.prank(users.owner);
        vm.expectRevert(Redeemer.InvalidRoot.selector);
        redeemer.setMerkleRoot(newMerkleRoot);
    }

    function testFuzz_Success_setMerkleRoot(bytes32 newMerkleRoot) public {
        // Given: Caller is the "owner".
        // When: Caller calls "setMerkleRoot".
        // Then: correct event is emitted.
        vm.prank(users.owner);
        vm.expectEmit(address(redeemer));
        emit Redeemer.MerkleRootSet(newMerkleRoot);
        redeemer.setMerkleRoot(newMerkleRoot);

        // And: New merkle root is set.
        assertTrue(redeemer.isRoot(newMerkleRoot));
        assertEq(redeemer.merkleRoot(), newMerkleRoot);
    }
}
