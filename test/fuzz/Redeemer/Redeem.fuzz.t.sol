/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Redeemer } from "../../../src/Redeemer.sol";
import { Redeemer_Fuzz_Test } from "./_Redeemer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "redeem" of contract "Redeemer".
 */
contract Redeem_Redeemer_Fuzz_Test is Redeemer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Redeemer_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_redeem_ZeroAmount(
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

        // When: Caller calls "redeem".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(invalidCaller);
        vm.expectRevert(Redeemer.ZeroAmount.selector);
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_InvalidCaller(
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

        // When: Caller calls "redeem".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(invalidCaller);
        vm.expectRevert(Redeemer.InvalidProof.selector);
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_InvalidMaxRedeemable(
        GlobalState memory globalState,
        UserState memory userState,
        uint64 invalidMaxRedeemable
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: maxRedeemable is not valid.
        vm.assume(userState.maxRedeemable != invalidMaxRedeemable);
        userState.maxRedeemable = invalidMaxRedeemable;

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "redeem".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert(Redeemer.InvalidProof.selector);
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_InvalidProof(
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

        // When: Caller calls "redeem".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert(Redeemer.InvalidProof.selector);
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_InvalidRoot(
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

        // When: Caller calls "redeem".
        // Then: The transaction should revert with "InvalidProof".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert(Redeemer.InvalidProof.selector);
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_AlreadyRedeemed(GlobalState memory globalState, UserState memory userState)
        public
    {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: User has already redeemed max amount.
        userState.redeemed = uint64(bound(userState.redeemed, userState.maxRedeemable, type(uint64).max));

        // And: State is persisted.
        setState(globalState, userState);

        // When: Caller calls "redeem".
        // Then: The transaction should revert with "AlreadyRedeemed".
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert(Redeemer.AlreadyRedeemed.selector);
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_InsufficientApprovalUser(
        GlobalState memory globalState,
        UserState memory userState,
        uint64 approval
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: State is persisted.
        setState(globalState, userState);

        uint256 redeemable = userState.maxRedeemable - userState.redeemed;
        uint256 amount = userState.amount < redeemable ? userState.amount : redeemable;

        // And: user approved the redeemable amount.
        approval = uint64(bound(approval, 0, amount - 1));
        vm.prank(userState.user);
        recoveryToken.approve(address(redeemer), approval);

        // When: Caller calls "redeem".
        // Then: The transaction should revert.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_InsufficientBalanceUser(GlobalState memory globalState, UserState memory userState)
        public
    {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: Balance of user is not sufficient.
        uint256 redeemable = userState.maxRedeemable - userState.redeemed;
        uint256 amount = userState.amount < redeemable ? userState.amount : redeemable;
        userState.balanceRT = uint64(bound(userState.balanceRT, 0, amount - 1));

        // And: State is persisted.
        setState(globalState, userState);

        // And: user approved the amount.
        vm.prank(userState.user);
        recoveryToken.approve(address(redeemer), amount);

        // When: Caller calls "redeem".
        // Then: The transaction should revert.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_InsufficientApprovalTreasury(
        GlobalState memory globalState,
        UserState memory userState,
        uint64 approval
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: State is persisted.
        setState(globalState, userState);

        uint256 redeemable = userState.maxRedeemable - userState.redeemed;
        uint256 amount = userState.amount < redeemable ? userState.amount : redeemable;

        // And: user approved the redeemable amount.
        vm.prank(userState.user);
        recoveryToken.approve(address(redeemer), userState.balanceRT);

        // And: treasury did not approve the redeemable amount.
        approval = uint64(bound(approval, 0, amount - 1));
        vm.prank(users.treasury);
        underlyingToken.approve(address(redeemer), approval);

        // When: Caller calls "redeem".
        // Then: The transaction should revert.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Revert_redeem_InsufficientBalanceTreasury(
        GlobalState memory globalState,
        UserState memory userState
    ) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: Balance of user is not sufficient.
        uint256 redeemable = userState.maxRedeemable - userState.redeemed;
        uint256 amount = userState.amount < redeemable ? userState.amount : redeemable;
        globalState.balanceUT = uint64(bound(globalState.balanceUT, 0, amount - 1));

        // And: State is persisted.
        setState(globalState, userState);

        // And: user approved the redeemable amount.
        vm.prank(userState.user);
        recoveryToken.approve(address(redeemer), userState.balanceRT);

        // And: treasury approved the redeemable amount.
        vm.prank(users.treasury);
        underlyingToken.approve(address(redeemer), globalState.balanceUT);

        // When: Caller calls "redeem".
        // Then: The transaction should revert.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);
    }

    function testFuzz_Success_redeem(GlobalState memory globalState, UserState memory userState) public {
        // Given: Valid state.
        givenValidState(globalState, userState);

        // And: State is persisted.
        setState(globalState, userState);

        // And: treasury approved the redeemable amount.
        vm.prank(users.treasury);
        underlyingToken.approve(address(redeemer), globalState.balanceUT);

        uint256 redeemable = userState.maxRedeemable - userState.redeemed;
        uint256 amount = userState.amount < redeemable ? userState.amount : redeemable;

        // And: user approved the amount.
        vm.prank(userState.user);
        recoveryToken.approve(address(redeemer), amount);

        // When: Caller calls "redeem".
        // Then: Correct event is emitted.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = userState.proof;
        vm.prank(userState.user);
        vm.expectEmit(address(redeemer));
        emit Redeemer.Redeemed(globalState.root, userState.user, amount);
        redeemer.redeem(userState.amount, userState.maxRedeemable, proofs);

        // And: User's balance of recovery tokens is updated.
        assertEq(recoveryToken.balanceOf(userState.user), userState.balanceRT - amount);

        // And: User's redeemed amount is updated.
        assertEq(redeemer.redeemed(globalState.root, userState.user), userState.redeemed + amount);

        // And: Treasury's balance of underlying tokens is updated.
        assertEq(underlyingToken.balanceOf(users.treasury), globalState.balanceUT - amount);
    }
}
