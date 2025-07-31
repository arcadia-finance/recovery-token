/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { InactiveRecoveryControllerHandler } from "./handlers/InactiveRecoveryControllerHandler.sol";
import { Invariant_Test } from "./Invariant.t.sol";

/**
 * @notice Invariant tests for when the "RecoveryController" is not activated.
 */
contract Inactive_Invariant_Test is Invariant_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

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
        state.addActor(users.holderSRT0);
        state.addActor(users.holderSRT1);
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
