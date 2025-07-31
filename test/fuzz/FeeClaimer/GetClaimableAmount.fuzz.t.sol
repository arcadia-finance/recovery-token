/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { FeeClaimer } from "../../../src/FeeClaimer.sol";
import { FeeClaimer_Fuzz_Test } from "./_FeeClaimer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getClaimableAmount" of contract "FeeClaimer".
 */
contract GetClaimableAmount_FeeClaimer_Fuzz_Test is FeeClaimer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        FeeClaimer_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getClaimableAmount_InvalidUser(
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

        // When: Caller calls "getClaimableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 claimable) =
            feeClaimer.getClaimableAmount(invalidUser, userState.maxClaimable, proofs);

        // Then: The correct values are returned.
        assertFalse(isValidProof);
        assertEq(claimable, 0);
    }

    function testFuzz_Revert_getClaimableAmount_InvalidMaxClaimable(
        GlobalState memory globalState,
        UserState memory userState,
        address caller,
        uint64 invalidMaxClaimable
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: maxClaimable is not valid.
        vm.assume(userState.maxClaimable != invalidMaxClaimable);
        userState.maxClaimable = invalidMaxClaimable;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getClaimableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 claimable) =
            feeClaimer.getClaimableAmount(userState.user, userState.maxClaimable, proofs);

        // Then: The correct values are returned.
        assertFalse(isValidProof);
        assertEq(claimable, 0);
    }

    function testFuzz_Revert_getClaimableAmount_InvalidProof(
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

        // When: Caller calls "getClaimableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 claimable) =
            feeClaimer.getClaimableAmount(userState.user, userState.maxClaimable, proofs);

        // Then: The correct values are returned.
        assertFalse(isValidProof);
        assertEq(claimable, 0);
    }

    function testFuzz_Revert_getClaimableAmount_InvalidRoot(
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

        // When: Caller calls "getClaimableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 claimable) =
            feeClaimer.getClaimableAmount(userState.user, userState.maxClaimable, proofs);

        // Then: The correct values are returned.
        assertFalse(isValidProof);
        assertEq(claimable, 0);
    }

    function testFuzz_Revert_getClaimableAmount_AlreadyClaimed(
        GlobalState memory globalState,
        UserState memory userState,
        address caller
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: User has already claimed max amount.
        userState.claimed = uint64(bound(userState.claimed, userState.maxClaimable, type(uint64).max));

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getClaimableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 claimable) =
            feeClaimer.getClaimableAmount(userState.user, userState.maxClaimable, proofs);

        // Then: The correct values are returned.
        assertTrue(isValidProof);
        assertEq(claimable, 0);
    }

    function testFuzz_Success_getClaimableAmount_ClaimableAmount(
        GlobalState memory globalState,
        UserState memory userState,
        address caller
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "getClaimableAmount".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(caller);
        (bool isValidProof, uint256 claimable) =
            feeClaimer.getClaimableAmount(userState.user, userState.maxClaimable, proofs);

        // Then: The correct values are returned.
        assertTrue(isValidProof);
        assertEq(claimable, userState.maxClaimable - userState.claimed);
    }
}
