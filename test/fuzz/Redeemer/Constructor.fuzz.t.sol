/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { RedeemerExtension } from "../../utils/extensions/RedeemerExtension.sol";
import { Redeemer_Fuzz_Test } from "./_Redeemer.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "Redeemer".
 */
contract Constructor_Redeemer_Fuzz_Test is Redeemer_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Redeemer_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_constructor(address owner, address treasury) public {
        RedeemerExtension redeemer_ = new RedeemerExtension(owner, address(recoveryController), treasury);

        assertEq(redeemer_.owner(), owner);
        assertEq(redeemer_.RECOVERY_TOKEN(), address(recoveryToken));
        assertEq(address(redeemer_.UNDERLYING_TOKEN()), address(underlyingToken));
        assertEq(redeemer_.treasury(), treasury);
    }
}
