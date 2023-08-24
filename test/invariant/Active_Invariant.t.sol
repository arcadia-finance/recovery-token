/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {Invariant_Test} from "./Invariant.t.sol";

/// @notice Common logic needed by all invariant tests.
contract Active_Invariant_Test is Invariant_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal initialSupplyWRT;
    uint256 internal lastSupplyRT;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public override {
        Invariant_Test.setUp();

        // Add actors who don't start with initial Recovery Tokens.
        state.addActor(users.alice);
        state.addActor(users.bob);

        // Mint the initial positions to "aggrievedUser".
        vm.startPrank(users.creator);
        mintWrappedRecoveryTokens(users.aggrievedUser0, 1e10);
        mintWrappedRecoveryTokens(users.aggrievedUser1, 1e10);

        // Set Recovery Contracts on active.
        recoveryController.activate();
        vm.stopPrank();

        lastSupplyRT = recoveryToken.totalSupply();
        initialSupplyWRT = wrappedRecoveryToken.totalSupply();
    }

    function mintWrappedRecoveryTokens(address to, uint256 amount) internal {
        recoveryController.mint(to, amount);
        state.addActor(to);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/

    function invariant_RtLastSupplyGeRtSupply() external {
        assertGe(lastSupplyRT, recoveryToken.totalSupply(), unicode"Invariant violation: WRT_supply_last < WRT_supply");
        lastSupplyRT = recoveryToken.totalSupply();
    }

    function invariant_WrtInitialSupplyGeWrtSupply() external {
        assertGe(
            initialSupplyWRT,
            wrappedRecoveryToken.totalSupply(),
            unicode"Invariant violation: WRT_supply_initial < WRT_supply"
        );
    }
}
