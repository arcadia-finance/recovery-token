/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

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
}
