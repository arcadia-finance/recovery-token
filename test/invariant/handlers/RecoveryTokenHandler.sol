/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {BaseHandler, SharedHandlerState} from "./BaseHandler.sol";
import {RecoveryToken} from "../../../src/RecoveryToken.sol";
import "../../utils/Constants.sol";

/// @dev This contract and not { Factory } is exposed to Foundry for invariant testing. The point is
/// to bound and restrict the inputs that get passed to the real-world contract to avoid getting reverts.
contract RecoveryTokenHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    RecoveryToken internal recoveryToken;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(SharedHandlerState state_, RecoveryToken recoveryToken_) BaseHandler(state_) {
        recoveryToken = recoveryToken_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function transfer(uint256 actorIndexSeed0, uint256 actorIndexSeed1, uint256 amount) external {
        address from = state.getActor(actorIndexSeed0);
        address to = state.getActor(actorIndexSeed1);

        amount = bound(amount, 0, recoveryToken.balanceOf(from));

        vm.prank(from);
        recoveryToken.transfer(to, amount);
    }

    function burn(uint256 actorIndexSeed, uint256 amount) external {
        address actor = state.getActor(actorIndexSeed);

        amount = bound(amount, 0, recoveryToken.balanceOf(actor));

        vm.prank(actor);
        recoveryToken.burn(amount);
    }
}
