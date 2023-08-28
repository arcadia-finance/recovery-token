/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {Base_Test} from "../Base.t.sol";

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {RecoveryControllerExtension} from "../utils/Extensions.sol";
import {RecoveryToken} from "../../src/RecoveryToken.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Integration_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ERC20Mock internal underlyingToken;
    RecoveryToken internal recoveryToken;
    RecoveryControllerExtension internal recoveryController;
    ERC20 wrappedRecoveryToken;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Deploy mocked Underlying Token contract.
        vm.startPrank(users.tokenCreator);
        underlyingToken = new ERC20Mock("Mocked Underlying Token","MUT",8);
        vm.stopPrank();

        // Deploy the base test contracts.
        vm.startPrank(users.creator);
        recoveryController = new RecoveryControllerExtension(address(underlyingToken));
        recoveryToken = RecoveryToken(recoveryController.recoveryToken());
        vm.stopPrank();
        wrappedRecoveryToken = ERC20(address(recoveryController));

        // Label the base test contracts.
        vm.label({account: address(recoveryController), newLabel: "RecoveryController"});
        vm.label({account: address(recoveryToken), newLabel: "RecoveryToken"});
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
