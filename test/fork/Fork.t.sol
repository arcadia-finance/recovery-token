/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

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
        address depositor;
        uint256 balanceWRT;
        uint256 depositAmountUT;
    }

    function setUp() public override {
        // Fork Optimism via Tenderly.
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        Base_Test.setUp();

        // Set Underlying Token.
        underlyingToken = ERC20(USDC_ADDRESS);
        vm.label({account: address(underlyingToken), newLabel: "UnderlyingToken"});

        // Deploy Recovery Contracts.
        deployRecoveryContracts();
    }

    function testFork_deposit(TestVars memory vars) public {
        // Given: Users are unique.
        givenUniqueUsers(vars);

        // Cache initial balances.
        uint256 initialBalanceDepositor = underlyingToken.balanceOf(vars.depositor);

        // And: "primaryHolder" has a valid "wrappedRecoveryToken" balance.
        vars = givenValidBalanceWRT(vars);

        // And: "depositor" has a valid "underlyingToken" balance of "depositAmountUT":
        vars = givenValidDepositAmountUT(vars);

        // And: State is persisted.
        vm.prank(users.owner);
        recoveryController.mint(vars.primaryHolder, vars.balanceWRT);
        deal(address(underlyingToken), vars.depositor, vars.depositAmountUT, true);

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

    function testFork_redeem_NonRecoveredPosition(TestVars memory vars) public {
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

        // Calculate rounding errors.
        uint256 maxRoundingError = vars.balanceWRT / 1e18 + 1;

        // Then: "depositAmountUT" of "underlyingToken" is transferred from "recoveryController" to "primaryHolder".
        assertApproxEqAbs(
            underlyingToken.balanceOf(vars.primaryHolder),
            initialBalancePrimaryHolder + vars.depositAmountUT,
            maxRoundingError
        );
        assertApproxEqAbs(underlyingToken.balanceOf(address(recoveryController)), 0, maxRoundingError);
    }

    function testFork_redeem_FullyRecoveredPosition(TestVars memory vars) public {
        // Given: users are unique.
        givenUniqueUsers(vars);

        // Cache initial balances.
        uint256 initialBalancePrimaryHolder = underlyingToken.balanceOf(vars.primaryHolder);

        // And: The position is fully redeemable.
        vars = givenPositionIsFullyRedeemable(vars);

        // And: State is persisted.
        mintAndDeposit(vars);

        // When: A "caller' redeems for "primaryHolder".
        if (vars.depositAmountUT != vars.balanceWRT) {
            vm.expectEmit(address(underlyingToken));
            emit Transfer(address(recoveryController), users.owner, vars.depositAmountUT - vars.balanceWRT);
        }
        vm.expectEmit(address(underlyingToken));
        emit Transfer(address(recoveryController), vars.primaryHolder, vars.balanceWRT);
        recoveryController.redeemUnderlying(vars.primaryHolder);

        // Then: "depositAmountUT" of "underlyingToken" is transferred from "recoveryController" to "primaryHolder".
        assertEq(underlyingToken.balanceOf(vars.primaryHolder), initialBalancePrimaryHolder + vars.balanceWRT);
        assertEq(underlyingToken.balanceOf(address(recoveryController)), 0);
        assertEq(underlyingToken.balanceOf(users.owner), vars.depositAmountUT - vars.balanceWRT);
    }

    // depositRecoveryTokens(uint256) and withdrawRecoveryTokens(uint256) call the same underlying function for
    // transfers of "underlyingToken" as redeemUnderlying(address), no need to fork test them separately.

    /*///////////////////////////////////////////////////////////////
                            HELPERS
    ///////////////////////////////////////////////////////////////*/

    function givenUniqueUsers(TestVars memory vars) internal view {
        vm.assume(vars.primaryHolder != address(0));
        vm.assume(vars.primaryHolder != address(recoveryController));
        vm.assume(vars.primaryHolder != vars.depositor);
        vm.assume(vars.depositor != address(0));
        vm.assume(vars.depositor != address(recoveryController));
    }

    function givenValidBalanceWRT(TestVars memory vars) internal view returns (TestVars memory) {
        // Constraints "balanceWRT":
        // - Greater than zero.
        vars.balanceWRT = bound(vars.balanceWRT, 1, type(uint256).max);

        return vars;
    }

    function givenValidDepositAmountUT(TestVars memory vars) internal view returns (TestVars memory) {
        // Constraints "depositAmountUT":
        // - Greater than zero.
        // - "totalSupply" does not overflow.
        // - "redeemablePerRTokenGlobal" does not overFlow.
        vars.depositAmountUT = bound(vars.depositAmountUT, 1, type(uint256).max - underlyingToken.totalSupply());
        vars.depositAmountUT = bound(vars.depositAmountUT, 1, type(uint256).max / 1e18);

        return vars;
    }

    function givenPositionIsNotFullyRedeemable(TestVars memory vars) internal view returns (TestVars memory) {
        givenValidDepositAmountUT(vars);

        // Constraints "balanceWRT":
        // - Position is not fully recovered: "depositAmountUT < balanceWRT"
        vars.balanceWRT = bound(vars.balanceWRT, vars.depositAmountUT + 1, type(uint256).max);

        return vars;
    }

    function givenPositionIsFullyRedeemable(TestVars memory vars) internal view returns (TestVars memory) {
        givenValidDepositAmountUT(vars);

        // Constraints "balanceWRT":
        // - Greater than zero.
        // - Position is fully recovered: "depositAmountUT >= balanceWRT".
        vars.balanceWRT = bound(vars.balanceWRT, 1, vars.depositAmountUT);

        return vars;
    }

    function mintAndDeposit(TestVars memory vars) internal {
        // Mint "balanceWRT" for "primaryHolder".
        vm.prank(users.owner);
        recoveryController.mint(vars.primaryHolder, vars.balanceWRT);

        // Activate Controller.
        vm.prank(users.owner);
        recoveryController.activate();

        // Deposit "depositAmountUT".
        deal(address(underlyingToken), vars.depositor, vars.depositAmountUT, true);
        vm.startPrank(vars.depositor);
        underlyingToken.approve(address(recoveryController), vars.depositAmountUT);
        recoveryController.depositUnderlying(vars.depositAmountUT);
        vm.stopPrank();
    }
}
