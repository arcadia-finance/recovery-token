/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";
import {Base_Test} from "../Base.t.sol";
import {RecoveryTokenHandler} from "./handlers/RecoveryTokenHandler.sol";
import {RecoveryControllerHandler} from "./handlers/RecoveryControllerHandler.sol";
import {SharedHandlerState} from "./SharedHandlerState.sol";

/// @notice Common logic needed by all invariant tests.
abstract contract Invariant_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    SharedHandlerState internal state;
    RecoveryTokenHandler internal recoveryTokenHandler;
    RecoveryControllerHandler internal recoveryControllerHandler;

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

        // Deploy handlers.
        recoveryTokenHandler = new RecoveryTokenHandler(state, recoveryToken);
        recoveryControllerHandler =
            new RecoveryControllerHandler(state, underlyingToken, recoveryToken, recoveryController);

        // Target handlers.
        targetContract(address(recoveryTokenHandler));
        targetContract(address(recoveryControllerHandler));

        // Exclude deployed contracts as senders.
        excludeSender(address(this));
        excludeSender(address(state));
        excludeSender(address(recoveryTokenHandler));
        excludeSender(address(recoveryControllerHandler));
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
