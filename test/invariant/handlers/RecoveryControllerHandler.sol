/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {BaseHandler, SharedHandlerState} from "./BaseHandler.sol";
import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
import {RecoveryToken} from "../../../src/RecoveryToken.sol";
import {RecoveryController} from "../../../src/RecoveryController.sol";
import "../../utils/Constants.sol";

/// @dev This contract and not { Factory } is exposed to Foundry for invariant testing. The point is
/// to bound and restrict the inputs that get passed to the real-world contract to avoid getting reverts.
contract RecoveryControllerHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    ERC20 internal underlyingToken;
    RecoveryToken internal recoveryToken;
    RecoveryController internal recoveryController;
    ERC20 internal wrappedRecoveryToken;

    /*//////////////////////////////////////////////////////////////////////////
                                GHOST VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public totalRedeemed;

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
    ) BaseHandler(state_) {
        underlyingToken = underlyingToken_;
        recoveryToken = recoveryToken_;
        recoveryController = recoveryController_;
        wrappedRecoveryToken = ERC20(address(recoveryController));
    }

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
        amount = bound(amount, 0, 1e9);
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

        vm.prank(actor);
        recoveryController.depositRecoveryTokens(amount);
    }

    function withdrawRecoveryTokens(uint256 actorIndexSeed, uint256 amount) external {
        address actor = state.getActor(actorIndexSeed);
        uint256 balanceWRT = wrappedRecoveryToken.balanceOf(actor);
        if (balanceWRT == 0) return;

        amount = bound(amount, 1, 1e10);

        vm.prank(actor);
        recoveryController.depositRecoveryTokens(amount);
    }
}
