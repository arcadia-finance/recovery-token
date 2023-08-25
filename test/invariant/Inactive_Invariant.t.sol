/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {Invariant_Test} from "./Invariant.t.sol";
import {InactiveRecoveryControllerHandler} from "./handlers/InactiveRecoveryControllerHandler.sol";

/// @notice Common logic needed by all invariant tests.
contract Inactive_Invariant_Test is Invariant_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal lastSupplyWRT;
    uint256 internal lastSupplyRT;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    InactiveRecoveryControllerHandler internal recoveryControllerHandler;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public override {
        Invariant_Test.setUp();

        // Deploy handlers.
        recoveryControllerHandler =
            new InactiveRecoveryControllerHandler(state, underlyingToken, recoveryToken, recoveryController);

        // Target handlers.
        targetContract(address(recoveryControllerHandler));

        // Exclude deployed contract as sender.
        excludeSender(address(recoveryControllerHandler));

        // Add actors who should receive Recovery Tokens.
        state.addActor(users.aggrievedUser0);
        state.addActor(users.aggrievedUser1);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/

    function invariant_RedeemablePerRTokenGlobalEqZero() external {
        assertEq(
            recoveryController.redeemablePerRTokenGlobal(), 0, "Invariant violation: RedeemablePerRTokenGlobal != 0"
        );
    }
}
