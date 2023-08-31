/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "../RecoveryController.fuzz.t.sol";

import {RecoveryControllerExtension} from "../../utils/Extensions.sol";

contract Deployment_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                            DEPLOYMENT
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Pass_deployment(address owner_) public {
        // Given:

        // When "owner_" deploys "recoveryController_".
        vm.prank(owner_);
        vm.expectEmit();
        emit ActivationSet(false);
        RecoveryControllerExtension recoveryController_ = new RecoveryControllerExtension(address(underlyingToken));

        // Then: the immutable variables are set on "recoveryController_".
        assertEq(recoveryController_.owner(), owner_);
        assertEq(recoveryController_.getUnderlying(), address(underlyingToken));
        assertEq(recoveryController_.decimals(), underlyingToken.decimals());
    }
}
