/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";
import {Base_Test} from "../Base.t.sol";
import {RecoveryTokenHandler} from "./handlers/RecoveryTokenHandler.sol";
import {RecoveryControllerHandler} from "./handlers/RecoveryControllerHandler.sol";
import {SharedHandlerState} from "./SharedHandlerState.sol";

/// @notice Common logic needed by all invariant tests.
abstract contract Invariant_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    SharedHandlerState internal state;
    RecoveryTokenHandler internal recoveryTokenHandler;
    RecoveryControllerHandler internal recoveryControllerHandler;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        Base_Test.setUp();

        deployUnderlyingAsset();
        deployRecoveryContracts();

        // Deploy shared state of all Handlers.
        state = new SharedHandlerState();

        // Deploy handlers.
        recoveryTokenHandler = new RecoveryTokenHandler(state, recoveryToken);
        recoveryControllerHandler = new RecoveryControllerHandler(state, recoveryController);

        // Target handlers.
        targetContract(address(recoveryTokenHandler));
        targetContract(address(recoveryControllerHandler));

        // Exclude deployed contracts as senders.
        excludeSender(address(this));
        excludeSender(address(state));
        excludeSender(address(recoveryTokenHandler));
        excludeSender(address(recoveryControllerHandler));
    }
}
