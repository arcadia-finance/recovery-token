/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Fork_Test } from "./Fork.t.sol";

/**
 * @notice Fork tests for "RecoveryToken".
 */
contract RecoveryController_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Fork_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_Success_deposit(TestVars memory vars) public {
        // Given: Users are unique.
        givenUniqueUsers(vars);

        // Cache initial balances.
        uint256 initialBalanceDepositor = underlyingToken.balanceOf(vars.depositor);

        // And: "primaryHolder" has a valid "stakedRecoveryToken" balance.
        vars = givenValidBalanceSRT(vars);

        // And: "depositor" has a valid "underlyingToken" balance of "depositAmountUT":
        vars = givenValidDepositAmountUT(vars);

        // And: State is persisted.
        vm.prank(users.owner);
        recoveryController.mint(vars.primaryHolder, vars.balanceSRT);
        vm.prank(USDC_WHALE);
        underlyingToken.transfer(vars.depositor, vars.depositAmountUT);

        // And: The Controller is active.
        vm.prank(users.owner);
        recoveryController.activate();

        // When: A "depositor" deposits "amount" of "underlyingToken".
        vm.startPrank(vars.depositor);
        underlyingToken.approve(address(recoveryController), vars.depositAmountUT);
        vm.expectEmit(address(underlyingToken));
        emit Transfer(vars.depositor, address(recoveryController), vars.depositAmountUT);
        recoveryController.depositUnderlying(vars.depositAmountUT);
        vm.stopPrank();

        // Then: "underlyingToken" is transferred from "depositor" to "recoveryController".
        assertEq(underlyingToken.balanceOf(vars.depositor), initialBalanceDepositor);
        assertEq(underlyingToken.balanceOf(address(recoveryController)), vars.depositAmountUT);
    }

    function testFork_Success_redeem_NonRecoveredPosition(TestVars memory vars) public {
        // Given: users are unique.
        givenUniqueUsers(vars);

        // Cache initial balances.
        uint256 initialBalancePrimaryHolder = underlyingToken.balanceOf(vars.primaryHolder);

        // And: The position is not fully redeemable.
        vars = givenPositionIsNotFullyRedeemable(vars);

        // And: State is persisted.
        mintAndDeposit(vars);

        // When: A "caller' redeems "primaryHolder".
        recoveryController.redeemUnderlying(vars.primaryHolder);

        // Then: "depositAmountUT" of "underlyingToken" is transferred from "recoveryController" to "primaryHolder".
        uint256 maxRoundingError = vars.balanceSRT / 1e18 + 1;
        assertApproxEqAbs(
            underlyingToken.balanceOf(vars.primaryHolder),
            initialBalancePrimaryHolder + vars.depositAmountUT,
            maxRoundingError
        );
        assertApproxEqAbs(underlyingToken.balanceOf(address(recoveryController)), 0, maxRoundingError);
    }

    function testFork_Success_redeem_FullyRecoveredPosition(TestVars memory vars) public {
        // Given: users are unique.
        givenUniqueUsers(vars);

        // Cache initial balances.
        uint256 initialBalancePrimaryHolder = underlyingToken.balanceOf(vars.primaryHolder);

        // And: The position is fully redeemable.
        vars = givenPositionIsFullyRedeemable(vars);

        // And: State is persisted.
        mintAndDeposit(vars);

        // When: A "caller' redeems for "primaryHolder".
        if (vars.depositAmountUT != vars.balanceSRT) {
            vm.expectEmit(address(underlyingToken));
            emit Transfer(address(recoveryController), users.owner, vars.depositAmountUT - vars.balanceSRT);
        }
        vm.expectEmit(address(underlyingToken));
        emit Transfer(address(recoveryController), vars.primaryHolder, vars.balanceSRT);
        recoveryController.redeemUnderlying(vars.primaryHolder);

        // Then: "depositAmountUT" of "underlyingToken" is transferred from "recoveryController" to "owner".
        assertEq(underlyingToken.balanceOf(vars.primaryHolder), initialBalancePrimaryHolder + vars.balanceSRT);
        assertEq(underlyingToken.balanceOf(address(recoveryController)), 0);
        assertEq(underlyingToken.balanceOf(users.owner), vars.depositAmountUT - vars.balanceSRT);
    }

    // stakeRecoveryTokens(uint256) and unstakeRecoveryTokens(uint256) call the same underlying function for
    // transfers of "underlyingToken" as redeemUnderlying(address), no need to fork test them separately.
}
