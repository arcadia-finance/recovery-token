/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Redeemer } from "../../../src/Redeemer.sol";
import { Redeemer_Fuzz_Test } from "./_Redeemer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getRedeemableAmount" of contract "Redeemer".
 */
contract GetRedeemableAmount_Redeemer_Fuzz_Test is Redeemer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Redeemer_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getRedeemableAmount_InvalidUser(
        GlobalState memory globalState,
        UserState memory userState,
        address caller,
        address invalidUser
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: user is not valid.
        vm.assume(userState.user != invalidUser);

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getRedeemableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 redeemable) =
            redeemer.getRedeemableAmount(invalidUser, userState.maxRedeemable, proofs);

        // Then: The correct values are returned.
        assertFalse(isValidProof);
        assertEq(redeemable, 0);
    }

    function testFuzz_Revert_getRedeemableAmount_InvalidMaxRedeemable(
        GlobalState memory globalState,
        UserState memory userState,
        address caller,
        uint64 invalidMaxRedeemable
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: maxRedeemable is not valid.
        vm.assume(userState.maxRedeemable != invalidMaxRedeemable);
        userState.maxRedeemable = invalidMaxRedeemable;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getRedeemableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 redeemable) =
            redeemer.getRedeemableAmount(userState.user, userState.maxRedeemable, proofs);

        // Then: The correct values are returned.
        assertFalse(isValidProof);
        assertEq(redeemable, 0);
    }

    function testFuzz_Revert_getRedeemableAmount_InvalidProof(
        GlobalState memory globalState,
        UserState memory userState,
        address caller,
        bytes32 invalidProof
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: proof is not valid.
        vm.assume(userState.proof != invalidProof);
        userState.proof = invalidProof;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getRedeemableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 redeemable) =
            redeemer.getRedeemableAmount(userState.user, userState.maxRedeemable, proofs);

        // Then: The correct values are returned.
        assertFalse(isValidProof);
        assertEq(redeemable, 0);
    }

    function testFuzz_Revert_getRedeemableAmount_InvalidRoot(
        GlobalState memory globalState,
        UserState memory userState,
        address caller,
        bytes32 invalidRoot
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: Root is not the same as the global root.
        vm.assume(globalState.root != invalidRoot);
        globalState.root = invalidRoot;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getRedeemableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 redeemable) =
            redeemer.getRedeemableAmount(userState.user, userState.maxRedeemable, proofs);

        // Then: The correct values are returned.
        assertFalse(isValidProof);
        assertEq(redeemable, 0);
    }

    function testFuzz_Revert_getRedeemableAmount_AlreadyRedeemed(
        GlobalState memory globalState,
        UserState memory userState,
        address caller
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: User has already redeemed max amount.
        userState.redeemed = uint64(bound(userState.redeemed, userState.maxRedeemable, type(uint64).max));

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getRedeemableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 redeemable) =
            redeemer.getRedeemableAmount(userState.user, userState.maxRedeemable, proofs);

        // Then: The correct values are returned.
        assertTrue(isValidProof);
        assertEq(redeemable, 0);
    }

    function testFuzz_Success_getRedeemableAmount_RedeemableAmount(
        GlobalState memory globalState,
        UserState memory userState,
        address caller
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getRedeemableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 redeemable) =
            redeemer.getRedeemableAmount(userState.user, userState.maxRedeemable, proofs);

        // Then: The correct values are returned.
        assertTrue(isValidProof);
        assertEq(redeemable, userState.maxRedeemable - userState.redeemed);
    }
}
