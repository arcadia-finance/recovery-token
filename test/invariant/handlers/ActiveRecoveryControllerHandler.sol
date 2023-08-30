/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryControllerHandler, SharedHandlerState} from "./RecoveryControllerHandler.sol";
import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
import {RecoveryToken} from "../../../src/RecoveryToken.sol";
import {RecoveryController} from "../../../src/RecoveryController.sol";

/// @dev This contract and not { Factory } is exposed to Foundry for invariant testing. The point is
/// to bound and restrict the inputs that get passed to the real-world contract to avoid getting reverts.
contract ActiveRecoveryControllerHandler is RecoveryControllerHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                GHOST VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(
        SharedHandlerState state_,
        ERC20 underlyingToken_,
        RecoveryToken recoveryToken_,
        RecoveryController recoveryController_
    ) RecoveryControllerHandler(state_, underlyingToken_, recoveryToken_, recoveryController_) {}

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function burn(uint256 actorIndexSeed, uint256 amount) external {
        address from = state.getActor(actorIndexSeed);

        amount = bound(amount, 0, recoveryController.balanceOf(from));

        vm.prank(recoveryController.owner());
        recoveryController.burn(from, amount);
    }

    function depositUnderlying(uint256 amount) external {
        // Reverts when there are no open positions.
        if (wrappedRecoveryToken.totalSupply() == 0) return;

        amount = bound(amount, 1, 1e9);
        deal(address(underlyingToken), msg.sender, amount, true);

        vm.startPrank(msg.sender);
        underlyingToken.approve(address(recoveryController), amount);
        recoveryController.depositUnderlying(amount);
        vm.stopPrank();
    }

    function redeemUnderlying(uint256 actorIndexSeed) external {
        address actor = state.getActor(actorIndexSeed);

        vm.prank(msg.sender);
        recoveryController.redeemUnderlying(actor);
    }

    function depositRecoveryTokens(uint256 actorIndexSeed, uint256 amount) external {
        address actor = state.getActor(actorIndexSeed);
        uint256 balanceRT = recoveryToken.balanceOf(actor);
        if (balanceRT == 0) return;

        amount = bound(amount, 1, balanceRT);

        vm.startPrank(actor);
        recoveryToken.approve(address(recoveryController), amount);
        recoveryController.depositRecoveryTokens(amount);
        vm.stopPrank();
    }

    function withdrawRecoveryTokens(uint256 actorIndexSeed, uint256 amount) external {
        address actor = state.getActor(actorIndexSeed);
        uint256 balanceWRT = wrappedRecoveryToken.balanceOf(actor);
        if (balanceWRT == 0) return;

        amount = bound(amount, 1, 1e10);

        vm.prank(actor);
        recoveryController.withdrawRecoveryTokens(amount);
    }
}
