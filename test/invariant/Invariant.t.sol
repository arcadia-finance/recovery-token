/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {Base_Test} from "../Base.t.sol";

import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";

import {SharedHandlerState} from "./SharedHandlerState.sol";

/**
 * @notice Common logic needed by all invariant tests.
 * @dev All invariants, especially those used to bound the solution space in fuzz tests, must be tested.
 */
abstract contract Invariant_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    SharedHandlerState internal state;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        Base_Test.setUp();

        deployUnderlyingAsset();
        deployRecoveryContracts();

        // Deploy shared state of all Handlers.
        state = new SharedHandlerState();

        // Exclude deployed contracts as senders.
        excludeSender(address(this));
        excludeSender(address(state));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/

    function invariant_WrtSupplyEqRtBalanceControllerAndRedeemedAmount() external {
        uint256 actorsLength = state.getActorsLength();
        uint256 totalRedeemed;
        for (uint256 i = 0; i < actorsLength; ++i) {
            address actor = state.actors(i);
            totalRedeemed += recoveryController.redeemed(actor);
        }
        assertEq(
            recoveryController.totalSupply(),
            recoveryToken.balanceOf(address(recoveryController)) + totalRedeemed,
            unicode"Invariant violation: WRT_supply != RT_balance_controller + Σi(redeemed_i)"
        );
    }

    function invariant_WrtBalanceGtRedeemed() external {
        uint256 actorsLength = state.getActorsLength();
        for (uint256 i = 0; i < actorsLength; ++i) {
            address actor = state.actors(i);
            uint256 wrtBalance = wrappedRecoveryToken.balanceOf(actor);
            if (wrtBalance > 0) {
                assertGt(
                    wrtBalance,
                    recoveryController.redeemed(actor),
                    unicode"Invariant violation: ∃i: WRT_balance_i > 0 ∧ WRT_balance_i <= redeemed_i"
                );
            }
        }
    }

    function invariant_RedeemablePerRTokenGlobalGeRedeemablePerRTokenLast() external {
        uint256 actorsLength = state.getActorsLength();
        for (uint256 i = 0; i < actorsLength; ++i) {
            address actor = state.actors(i);
            assertGe(
                recoveryController.redeemablePerRTokenGlobal(),
                recoveryController.redeemablePerRTokenLast(actor),
                unicode"Invariant violation: ∃i: RedeemablePerRTokenGlobal < RedeemablePerRTokenLast_i"
            );
        }
    }

    function invariant_UtBalanceControllerGeTotalRedeemable() external {
        uint256 actorsLength = state.getActorsLength();
        uint256 totalRedeemable;
        for (uint256 i = 0; i < actorsLength; ++i) {
            address actor = state.actors(i);
            totalRedeemable += recoveryController.previewRedeemable(actor);
        }
        assertGe(
            underlyingToken.balanceOf(address(recoveryController)),
            totalRedeemable,
            unicode"Invariant violation: UT_balance_controller < Σi(redeemable_i)"
        );
    }
}
