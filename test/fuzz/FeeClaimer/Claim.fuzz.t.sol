/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { FeeClaimer } from "../../../src/FeeClaimer.sol";
import { FeeClaimer_Fuzz_Test } from "./_FeeClaimer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "claim" of contract "FeeClaimer".
 */
contract Claim_FeeClaimer_Fuzz_Test is FeeClaimer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        FeeClaimer_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_claim_ZeroAmount(
        GlobalState memory globalState,
        UserState memory userState,
        address invalidCaller
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: amount is zero.
        userState.amount = 0;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "claim".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(invalidCaller);
        vm.expectRevert(FeeClaimer.ZeroAmount.selector);
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_InvalidCaller(
        GlobalState memory globalState,
        UserState memory userState,
        address invalidCaller
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: caller is not valid.
        vm.assume(userState.user != invalidCaller);

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "claim".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(invalidCaller);
        vm.expectRevert(FeeClaimer.InvalidProof.selector);
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_InvalidMaxClaimable(
        GlobalState memory globalState,
        UserState memory userState,
        uint64 invalidMaxClaimable
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: maxClaimable is not valid.
        vm.assume(userState.maxClaimable != invalidMaxClaimable);
        userState.maxClaimable = invalidMaxClaimable;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "claim".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert(FeeClaimer.InvalidProof.selector);
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_InvalidProof(
        GlobalState memory globalState,
        UserState memory userState,
        bytes32 invalidProof
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: proof is not valid.
        vm.assume(userState.proof != invalidProof);
        userState.proof = invalidProof;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "claim".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert(FeeClaimer.InvalidProof.selector);
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_InvalidRoot(
        GlobalState memory globalState,
        UserState memory userState,
        bytes32 invalidRoot
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: Root is not the same as the global root.
        vm.assume(globalState.root != invalidRoot);
        globalState.root = invalidRoot;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "claim".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert(FeeClaimer.InvalidProof.selector);
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_AlreadyClaimed(GlobalState memory globalState, UserState memory userState) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: User has already claimed max amount.
        userState.claimed = uint64(bound(userState.claimed, userState.maxClaimable, type(uint64).max));

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "claim".
        // Then: The transaction should revert with "AlreadyClaimed".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert(FeeClaimer.AlreadyClaimed.selector);
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_InsufficientApprovalUser(
        GlobalState memory globalState,
        UserState memory userState,
        uint64 approval
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: State is persisted.
        setState(globalState, userState);

        uint256 claimable = userState.maxClaimable - userState.claimed;
        uint256 amount = userState.amount < claimable ? userState.amount : claimable;

        // And: user approved the claimable amount.
        approval = uint64(bound(approval, 0, amount - 1));
        vm.prank(userState.user);
        recoveryToken.approve(address(feeClaimer), approval);

        // When: Caller calls "claim".
        // Then: The transaction should revert.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_InsufficientBalanceUser(GlobalState memory globalState, UserState memory userState)
        public
    {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: Balance of user is not sufficient.
        uint256 claimable = userState.maxClaimable - userState.claimed;
        uint256 amount = userState.amount < claimable ? userState.amount : claimable;
        userState.balanceRT = uint64(bound(userState.balanceRT, 0, amount - 1));

        // And: State is persisted.
        setState(globalState, userState);

        // And: user approved the amount.
        vm.prank(userState.user);
        recoveryToken.approve(address(feeClaimer), amount);

        // When: Caller calls "claim".
        // Then: The transaction should revert.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_InsufficientApprovalTreasury(
        GlobalState memory globalState,
        UserState memory userState,
        uint64 approval
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: State is persisted.
        setState(globalState, userState);

        uint256 claimable = userState.maxClaimable - userState.claimed;
        uint256 amount = userState.amount < claimable ? userState.amount : claimable;

        // And: user approved the claimable amount.
        vm.prank(userState.user);
        recoveryToken.approve(address(feeClaimer), userState.balanceRT);

        // And: treasury did not approve the claimable amount.
        approval = uint64(bound(approval, 0, amount - 1));
        vm.prank(users.treasury);
        underlyingToken.approve(address(feeClaimer), approval);

        // When: Caller calls "claim".
        // Then: The transaction should revert.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Revert_claim_InsufficientBalanceTreasury(
        GlobalState memory globalState,
        UserState memory userState
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: Balance of user is not sufficient.
        uint256 claimable = userState.maxClaimable - userState.claimed;
        uint256 amount = userState.amount < claimable ? userState.amount : claimable;
        globalState.balanceUT = uint64(bound(globalState.balanceUT, 0, amount - 1));

        // And: State is persisted.
        setState(globalState, userState);

        // And: user approved the claimable amount.
        vm.prank(userState.user);
        recoveryToken.approve(address(feeClaimer), userState.balanceRT);

        // And: treasury approved the claimable amount.
        vm.prank(users.treasury);
        underlyingToken.approve(address(feeClaimer), globalState.balanceUT);

        // When: Caller calls "claim".
        // Then: The transaction should revert.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);
    }

    function testFuzz_Success_claim(GlobalState memory globalState, UserState memory userState) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: State is persisted.
        setState(globalState, userState);

        // And: treasury approved the claimable amount.
        vm.prank(users.treasury);
        underlyingToken.approve(address(feeClaimer), globalState.balanceUT);

        uint256 claimable = userState.maxClaimable - userState.claimed;
        uint256 amount = userState.amount < claimable ? userState.amount : claimable;

        // And: user approved the amount.
        vm.prank(userState.user);
        recoveryToken.approve(address(feeClaimer), amount);

        // When: Caller calls "claim".
        // Then: Correct event is emitted.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectEmit(address(feeClaimer));
        emit FeeClaimer.Claimed(globalState.root, userState.user, amount);
        feeClaimer.claim(userState.amount, userState.maxClaimable, proofs);

        // And: User's balance of recovery tokens is updated.
        assertEq(recoveryToken.balanceOf(userState.user), userState.balanceRT - amount);

        // And: User's claimed amount is updated.
        assertEq(feeClaimer.claimed(globalState.root, userState.user), userState.claimed + amount);

        // And: Treasury's balance of underlying tokens is updated.
        assertEq(underlyingToken.balanceOf(users.treasury), globalState.balanceUT - amount);
    }
}
