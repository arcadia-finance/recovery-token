/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { CommonBase } from "../../../lib/forge-std/src/Base.sol";
import { SharedHandlerState } from "../SharedHandlerState.sol";
import { StdCheats } from "../../../lib/forge-std/src/StdCheats.sol";
import { StdUtils } from "../../../lib/forge-std/src/StdUtils.sol";

/**
 * @notice Base contract with common logic needed by all handler contracts.
 */
abstract contract BaseHandler is CommonBase, StdCheats, StdUtils {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    SharedHandlerState internal immutable state;
    address internal currentActor;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(SharedHandlerState state_) {
        state = state_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = state.getActor(actorIndexSeed);
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }
}
