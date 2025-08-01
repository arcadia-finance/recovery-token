/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";
import { RecoveryControllerExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "constructor" of "RecoveryController".
 */
contract Constructor_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_constructor(address owner_) public {
        // Given:

        // When "owner_" deploys "recoveryController_".
        vm.prank(owner_);
        vm.expectEmit();
        emit ActivationSet(false);
        RecoveryControllerExtension recoveryController_ = new RecoveryControllerExtension(address(underlyingToken));

        // Then: the immutable variables are set on "recoveryController_".
        assertEq(recoveryController_.owner(), owner_);
        assertEq(address(recoveryController_.UNDERLYING_TOKEN()), address(underlyingToken));
        assertEq(recoveryController_.decimals(), underlyingToken.decimals());
    }
}
