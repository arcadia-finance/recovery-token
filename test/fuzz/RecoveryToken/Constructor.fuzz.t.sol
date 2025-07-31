/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryToken_Fuzz_Test } from "./_RecoveryToken.fuzz.t.sol";
import { RecoveryTokenExtension } from "../../utils/extensions/RecoveryTokenExtension.sol";

/**
 * @notice Fuzz tests for the "constructor" of "RecoveryToken".
 */
contract Constructor_RecoveryToken_Fuzz_Test is RecoveryToken_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryToken_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Success_deployment(address recoveryController_, uint8 decimals_) public {
        recoveryTokenExtension = new RecoveryTokenExtension(recoveryController_, decimals_);

        assertEq(recoveryTokenExtension.getRecoveryController(), recoveryController_);
        assertEq(recoveryTokenExtension.decimals(), decimals_);
    }
}
