/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Constants} from "./utils/Constants.sol";
import {Errors} from "./utils/Errors.sol";
import {Events} from "./utils/Events.sol";
import {ERC20, ERC20Mock} from "./mocks/ERC20Mock.sol";
import {RecoveryToken} from "../src/RecoveryToken.sol";
import {RecoveryController} from "../src/RecoveryController.sol";
import {Users} from "./utils/Types.sol";
import {Utils} from "./utils/Utils.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Events, Errors, Utils {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users public users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ERC20 internal underlyingToken;
    RecoveryToken internal recoveryToken;
    RecoveryController internal recoveryController;
    ERC20 internal wrappedRecoveryToken;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users for testing
        users = Users({
            creator: createUser("creator"),
            owner: users.creator,
            tokenCreator: createUser("tokenCreator"),
            aggrievedUser0: createUser("aggrievedUser0"),
            aggrievedUser1: createUser("aggrievedUser1"),
            alice: createUser("alice"),
            bob: createUser("bob")
        });
        users.owner = users.creator;
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

    function deployUnderlyingAsset() internal {
        // Deploy mocked Underlying Asset.
        vm.prank(users.tokenCreator);
        underlyingToken = new ERC20Mock("Mocked Underlying Token","MUT",8);

        // Label the contract.
        vm.label({account: address(underlyingToken), newLabel: "UnderlyingToken"});
    }

    function deployRecoveryContracts() internal {
        // Deploy Recovery contracts.
        vm.prank(users.creator);
        recoveryController = new RecoveryController(address(underlyingToken));
        wrappedRecoveryToken = ERC20(address(recoveryController));
        recoveryToken = RecoveryToken(recoveryController.recoveryToken());

        // Label the contracts.
        vm.label({account: address(recoveryToken), newLabel: "RecoveryToken"});
        vm.label({account: address(recoveryController), newLabel: "RecoveryController"});
    }
}
