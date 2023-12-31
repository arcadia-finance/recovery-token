/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {Invariant_Test} from "./Invariant.t.sol";

import {RecoveryTokenHandler} from "./handlers/RecoveryTokenHandler.sol";
import {ActiveRecoveryControllerHandler} from "./handlers/ActiveRecoveryControllerHandler.sol";

/**
 * @notice Invariant tests for when the "RecoveryController" is activated.
 */
contract ActiveState_Invariant_Test is Invariant_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal initialSupplyWRT;
    uint256 internal lastSupplyRT;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    RecoveryTokenHandler internal recoveryTokenHandler;
    ActiveRecoveryControllerHandler internal recoveryControllerHandler;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public override {
        Invariant_Test.setUp();

        // Deploy handlers.
        recoveryTokenHandler = new RecoveryTokenHandler(state, recoveryToken);
        recoveryControllerHandler =
            new ActiveRecoveryControllerHandler(state, underlyingToken, recoveryToken, recoveryController);

        // Target handlers.
        targetContract(address(recoveryTokenHandler));
        targetContract(address(recoveryControllerHandler));

        // Exclude deployed contracts as senders.
        excludeSender(address(recoveryTokenHandler));
        excludeSender(address(recoveryControllerHandler));

        // Add actors who don't start with initial Recovery Tokens.
        state.addActor(users.alice);
        state.addActor(users.bob);

        // Mint the initial positions to users.
        vm.startPrank(users.creator);
        mintWrappedRecoveryTokens(users.holderWRT0, 1e10);
        mintWrappedRecoveryTokens(users.holderWRT1, 1e10);

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
