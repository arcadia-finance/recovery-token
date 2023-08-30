/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import {BaseHandler, SharedHandlerState} from "./BaseHandler.sol";
import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
import {RecoveryToken} from "../../../src/RecoveryToken.sol";
import {RecoveryController} from "../../../src/RecoveryController.sol";

/// @dev This contract and not { Factory } is exposed to Foundry for invariant testing. The point is
/// to bound and restrict the inputs that get passed to the real-world contract to avoid getting reverts.
abstract contract RecoveryControllerHandler is BaseHandler {
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
}
