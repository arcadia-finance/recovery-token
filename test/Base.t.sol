/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Constants} from "./utils/Constants.sol";
import {Errors} from "./utils/Errors.sol";
import {Events} from "./utils/Events.sol";
import {RecoveryControllerExtension} from "./utils/Extensions.sol";
import {Users} from "./utils/Types.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {RecoveryController} from "../src/RecoveryController.sol";
import {RecoveryToken} from "../src/RecoveryToken.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Events, Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ERC20Mock internal underlyingToken;
    RecoveryControllerExtension internal recoveryController;
    RecoveryToken internal recoveryToken;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users for testing
        users = Users({
            creator: createUser("creator"),
            tokenCreator: createUser("tokenCreator"),
            aggrievedUser0: createUser("aggrievedUser0"),
            aggrievedUser1: createUser("aggrievedUser1")
        });

        // Deploy mocked Underlying Token contract.
        vm.startPrank(users.tokenCreator);
        underlyingToken = new ERC20Mock("Mocked Underlying Token","MUT",8);
        vm.stopPrank();

        // Deploy the base test contracts.
        vm.startPrank(users.creator);
        recoveryController = new RecoveryControllerExtension(address(underlyingToken));
        recoveryToken = RecoveryToken(recoveryController.getRecoveryToken());
        vm.stopPrank();

        // Label the base test contracts.
        vm.label({account: address(recoveryController), newLabel: "RecoveryController"});
        vm.label({account: address(recoveryToken), newLabel: "RecoveryToken"});
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({account: user, newBalance: 100 ether});
        return user;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
