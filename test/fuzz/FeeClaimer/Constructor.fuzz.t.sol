/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { FeeClaimerExtension } from "../../utils/extensions/FeeClaimerExtension.sol";
import { FeeClaimer_Fuzz_Test } from "./_FeeClaimer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "FeeClaimer".
 */
contract Constructor_FeeClaimer_Fuzz_Test is FeeClaimer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        FeeClaimer_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_constructor(address owner, address treasury) public {
        FeeClaimerExtension feeClaimer_ = new FeeClaimerExtension(owner, address(recoveryController), treasury);

        assertEq(feeClaimer_.owner(), owner);
        assertEq(feeClaimer_.RECOVERY_TOKEN(), address(recoveryToken));
        assertEq(address(feeClaimer_.UNDERLYING_TOKEN()), address(underlyingToken));
        assertEq(feeClaimer_.treasury(), treasury);
    }
}
