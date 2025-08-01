/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryController_Fuzz_Test } from "./_RecoveryController.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "distributeUnderlying" of "RecoveryController".
 */
contract DistributeUnderlying_RecoveryController_Fuzz_Test is RecoveryController_Fuzz_Test {
    using stdStorage for StdStorage;

    /* ///////////////////////////////////////////////////////////////
                                SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                                TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Success_distributeUnderlying(uint256 redeemablePerRTokenGlobal, uint256 amount, uint256 supplyWRT)
        public
    {
        // Given: supplyWRT is non-zero.
        vm.assume(supplyWRT > 0);

        // And: New redeemablePerRTokenGlobal does not overflow.
        amount = bound(amount, 0, type(uint256).max / 1e18);
        uint256 delta = amount * 1e18 / supplyWRT;
        redeemablePerRTokenGlobal = bound(redeemablePerRTokenGlobal, 0, type(uint256).max - delta);

        // And: State is persisted.
        stdstore.target(address(recoveryControllerExtension)).sig(
            recoveryControllerExtension.redeemablePerRTokenGlobal.selector
        ).checked_write(redeemablePerRTokenGlobal);
        stdstore.target(address(recoveryControllerExtension)).sig(recoveryControllerExtension.totalSupply.selector)
            .checked_write(supplyWRT);

        // When: "amount" of "underlyingToken" is distributed.
        recoveryControllerExtension.distributeUnderlying(amount);

        // Then: "redeemablePerRTokenGlobal" is increased with "delta".
        assertEq(recoveryControllerExtension.redeemablePerRTokenGlobal(), redeemablePerRTokenGlobal + delta);
    }
}
