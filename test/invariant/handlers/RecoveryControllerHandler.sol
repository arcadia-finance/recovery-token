/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {BaseHandler, SharedHandlerState} from "./BaseHandler.sol";
import {RecoveryController} from "../../../src/RecoveryController.sol";
import "../../utils/Constants.sol";

/// @dev This contract and not { Factory } is exposed to Foundry for invariant testing. The point is
/// to bound and restrict the inputs that get passed to the real-world contract to avoid getting reverts.
contract RecoveryControllerHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    RecoveryController internal recoveryController;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(SharedHandlerState state_, RecoveryController recoveryController_) BaseHandler(state_) {
        recoveryController = recoveryController_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
}
