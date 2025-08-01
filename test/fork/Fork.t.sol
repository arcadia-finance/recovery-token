/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Base_Test } from "../Base.t.sol";
import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Common logic needed by all fork tests.
 * @dev Each function that interacts with an external and deployed contract, must be fork tested with the actual deployed bytecode of said contract.
 * @dev While not always possible (since unlike with the fuzz tests, it is not possible to work with extension with the necessary getters and setter),
 * as much of the possible state configurations must be tested.
 */
abstract contract Fork_Test is Base_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    address internal constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant USDC_ADMIN = 0x4fc7850364958d97B4d3f5A08f79db2493f8cA44; // Optimism
    address internal constant USDC_WHALE = 0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3;
    string internal RPC_URL = vm.envString("RPC_URL");

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    ///////////////////////////////////////////////////////////////*/

    uint256 internal fork;

    struct TestVars {
        address primaryHolder;
        address depositor;
        uint256 balanceWRT;
        uint256 depositAmountUT;
    }

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Fork Optimism via Tenderly.
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        Base_Test.setUp();

        // Set Underlying Token.
        underlyingToken = ERC20(USDC_ADDRESS);
        vm.label({ account: address(underlyingToken), newLabel: "UnderlyingToken" });

        // Deploy Recovery Contracts.
        deployRecoveryContracts();
    }

    /*///////////////////////////////////////////////////////////////
                            HELPERS
    ///////////////////////////////////////////////////////////////*/

    function givenUniqueUsers(TestVars memory vars) internal view {
        vm.assume(vars.primaryHolder != address(0));
        vm.assume(vars.primaryHolder != address(recoveryController));
        vm.assume(vars.primaryHolder != vars.depositor);
        vm.assume(vars.primaryHolder != USDC_ADDRESS);
        vm.assume(vars.primaryHolder != USDC_ADMIN);
        vm.assume(vars.primaryHolder != USDC_WHALE);
        vm.assume(vars.depositor != address(0));
        vm.assume(vars.depositor != address(recoveryController));
        vm.assume(vars.depositor != USDC_ADDRESS);
        vm.assume(vars.depositor != USDC_ADMIN);
        vm.assume(vars.depositor != USDC_WHALE);
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
        vars.depositAmountUT = bound(vars.depositAmountUT, 1, underlyingToken.balanceOf(USDC_WHALE));
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
        vm.prank(USDC_WHALE);
        underlyingToken.transfer(vars.depositor, vars.depositAmountUT);

        vm.startPrank(vars.depositor);
        underlyingToken.approve(address(recoveryController), vars.depositAmountUT);
        recoveryController.depositUnderlying(vars.depositAmountUT);
        vm.stopPrank();
    }
}
