/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {Invariant_Test} from "./Invariant.t.sol";
import {RecoveryControllerHandler} from "./handlers/RecoveryControllerHandler.sol";

/// @dev Invariant tests for RecoveryController.
contract RecoveryController_Invariant_Test is Invariant_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                      VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    RecoveryControllerHandler internal recoveryControllerHandler;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        Invariant_Test.setUp();
        recoveryControllerHandler = new RecoveryControllerHandler();
        // We only want to target function calls inside the FactoryHandler contract
        targetContract(address(recoveryControllerHandler));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/
    // function invariant_() public {}
}
