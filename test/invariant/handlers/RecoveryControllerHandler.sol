/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { BaseHandler, SharedHandlerState } from "./BaseHandler.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { RecoveryController } from "../../../src/RecoveryController.sol";
import { RecoveryToken } from "../../../src/RecoveryToken.sol";

/**
 * @notice Contract with common logic needed by all "RecoveryController" handler contracts.
 */
abstract contract RecoveryControllerHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    ERC20 internal underlyingToken;
    RecoveryToken internal recoveryToken;
    RecoveryController internal recoveryController;
    ERC20 internal stakedRecoveryToken;

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
        stakedRecoveryToken = ERC20(address(recoveryController));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function mintRecoveryTokens(uint256 actorIndexSeed, uint256 amount) external {
        address to = state.getActor(actorIndexSeed);

        amount = bound(amount, 0, 1e10);

        vm.prank(recoveryController.owner());
        recoveryController.mintRecoveryTokens(to, amount);
    }
}
