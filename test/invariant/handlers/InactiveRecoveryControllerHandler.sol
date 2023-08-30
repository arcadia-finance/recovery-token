/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import {RecoveryControllerHandler, SharedHandlerState} from "./RecoveryControllerHandler.sol";
import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
import {RecoveryToken} from "../../../src/RecoveryToken.sol";
import {RecoveryController} from "../../../src/RecoveryController.sol";

/// @dev This contract and not { Factory } is exposed to Foundry for invariant testing. The point is
/// to bound and restrict the inputs that get passed to the real-world contract to avoid getting reverts.
contract InactiveRecoveryControllerHandler is RecoveryControllerHandler {
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

    function mint(uint256 actorIndexSeed, uint256 amount) external {
        address to = state.getActor(actorIndexSeed);

        amount = bound(amount, 0, 1e10);

        vm.prank(recoveryController.owner());
        recoveryController.mint(to, amount);
    }

    function burn(uint256 actorIndexSeed, uint256 amount) external {
        address from = state.getActor(actorIndexSeed);

        amount = bound(amount, 0, recoveryController.balanceOf(from));

        vm.prank(recoveryController.owner());
        recoveryController.burn(from, amount);
    }
}
