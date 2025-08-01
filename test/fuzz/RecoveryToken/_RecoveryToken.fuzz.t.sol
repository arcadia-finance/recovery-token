/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Fuzz_Test } from "../Fuzz.t.sol";
import { RecoveryTokenExtension } from "../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "RecoveryToken" fuzz tests.
 */
abstract contract RecoveryToken_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    RecoveryTokenExtension internal recoveryTokenExtension;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Fuzz_Test.setUp();

        // Deploy Recovery Token contract.
        recoveryTokenExtension = new RecoveryTokenExtension(address(recoveryController), underlyingToken.decimals());

        // Label the contract.
        vm.label({ account: address(recoveryToken), newLabel: "RecoveryToken" });
    }
}
