/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.13;

import {Base_Test} from "../Base.t.sol";
import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";

contract Fork_Test is Base_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    address internal constant USDC_ADDRESS = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    string internal RPC_URL = vm.envString("RPC_URL");

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    ///////////////////////////////////////////////////////////////*/

    uint256 internal fork;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    struct TestVars {
        address primaryHolder;
        address secondaryHolder;
        address depositor;
        uint256 balanceWRT;
        uint256 depositAmountUT;
        uint256 redeemAmount;
        uint256 withdrawAmountRT;
        uint256 depositAmountRT;
    }

    function setUp() public override {
        // Fork Optimism via Tenderly.
        fork = vm.createFork(RPC_URL);

        // Set Underlying Token.
        underlyingToken = ERC20(USDC_ADDRESS);
        vm.label({account: address(underlyingToken), newLabel: "UnderlyingToken"});

        // Deploy Recovery Contracts.
        deployRecoveryContracts();
    }

    function testFork_deposit(TestVars memory vars) public {
        // Given: Users are unique.
        givenUniqueUsers(vars);

        // And: "primaryHolder" has a valid "wrappedRecoveryToken" balance.
        vars = givenValidBalanceWRT(vars);

        // And: "depositor" has a valid "underlyingToken" balance of "depositAmountUT":
        vars = givenValidDepositAmountUT(vars);

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
        assertEq(underlyingToken.balanceOf(vars.depositor), 0);
        assertEq(underlyingToken.balanceOf(address(recoveryController)), vars.depositAmountUT);
    }

    function testFork_redeem_NonRecoveredPosition(TestVars memory vars) public {
        // Given: users are unique.
        givenUniqueUsers(vars);

        // And: "primaryHolder" has a valid "wrappedRecoveryToken" balance.
        vars = givenValidBalanceWRT(vars);

        // And: The Controller is active.
        vm.prank(users.owner);
        recoveryController.activate();

        // And: No Withdrawals/Deposits of "recoveryToken".
        vars.withdrawAmountRT = 0;
        vars.depositAmountRT = 0;

        // And: The position is not fully redeemable.
        vars = givenPositionIsNotFullyRedeemable(vars);

        // When: A "caller' redeems "primaryHolder".
        recoveryController.redeemUnderlying(vars.primaryHolder);

        // Then: "depositAmountUT" of "underlyingToken" is transferred from "recoveryController" to "primaryHolder".
        assertEq(underlyingToken.balanceOf(vars.primaryHolder), vars.depositAmountUT);
        assertEq(underlyingToken.balanceOf(address(recoveryController)), 0);
    }

    /*///////////////////////////////////////////////////////////////
                            HELPERS
    ///////////////////////////////////////////////////////////////*/

    function givenUniqueUsers(TestVars memory vars) internal view {
        vm.assume(vars.primaryHolder != address(recoveryController));
        vm.assume(vars.primaryHolder != vars.secondaryHolder);
        vm.assume(vars.primaryHolder != vars.depositor);
        vm.assume(vars.secondaryHolder != address(recoveryController));
        vm.assume(vars.secondaryHolder != vars.depositor);
        vm.assume(vars.depositor != address(recoveryController));
    }

    function givenValidBalanceWRT(TestVars memory vars) internal returns (TestVars memory) {
        // Constraints "balanceWRT":
        // - Greater than zero.
        vars.balanceWRT = bound(vars.balanceWRT, 1, type(uint256).max);
        vm.prank(users.owner);
        recoveryController.mint(vars.primaryHolder, vars.balanceWRT);

        return vars;
    }

    function givenValidDepositAmountUT(TestVars memory vars) internal returns (TestVars memory) {
        // Constraints "depositAmountUT":
        // - Greater than zero.
        // - "totalSupply" does not overflow.
        // - "redeemablePerRTokenGlobal" does not overFlow.
        vars.depositAmountUT = bound(vars.depositAmountUT, 1, type(uint256).max - underlyingToken.totalSupply());
        vars.depositAmountUT = bound(vars.depositAmountUT, 1, type(uint256).max / 1e18);
        deal(address(underlyingToken), vars.depositor, vars.depositAmountUT, true);

        return vars;
    }

    function givenPositionIsNotFullyRedeemable(TestVars memory vars) internal returns (TestVars memory) {
        // Constraints "depositAmountUT":
        // - Greater than zero.
        // - "totalSupply" does not overflow.
        // - "redeemablePerRTokenGlobal" does not overFlow.
        // - Position is not fully recoverd: "depositAmountUT < balanceWRT" -> balanceWRT > 1
        vars.depositAmountUT = bound(vars.depositAmountUT, 1, type(uint256).max - underlyingToken.totalSupply());
        vars.depositAmountUT = bound(vars.depositAmountUT, 1, type(uint256).max / 1e18);
        vm.assume(vars.balanceWRT > 1);
        vars.depositAmountUT = bound(vars.depositAmountUT, 1, vars.balanceWRT - 1);

        deal(address(underlyingToken), vars.depositor, vars.depositAmountUT, true);

        vm.startPrank(vars.depositor);
        underlyingToken.approve(address(recoveryController), vars.depositAmountUT);
        recoveryController.depositUnderlying(vars.depositAmountUT);
        vm.stopPrank();

        return vars;
    }
}
