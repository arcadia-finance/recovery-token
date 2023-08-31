/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {RecoveryController_Fuzz_Test} from "../RecoveryController.fuzz.t.sol";

/**
 * @notice Fuzz tests for the transfer logic of "RecoveryController".
 */
contract TransferLogic_Fuzz_Test is RecoveryController_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RecoveryController_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_transfer(address aggrievedUser, address to, uint256 initialBalance, uint256 amount)
        public
    {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryControllerExtension), aggrievedUser, initialBalance);

        // When: "aggrievedUser" transfers "amount" to "to".
        // Then: Transaction should revert with "NoTransfersAllowed".
        vm.prank(aggrievedUser);
        vm.expectRevert(NoTransfersAllowed.selector);
        recoveryControllerExtension.transfer(to, amount);
    }

    function testFuzz_Revert_transferFrom(
        address caller,
        address aggrievedUser,
        address to,
        uint256 allowance,
        uint256 initialBalance,
        uint256 amount
    ) public {
        // Given "aggrievedUser" has "initialBalance" tokens.
        deal(address(recoveryControllerExtension), aggrievedUser, initialBalance);
        // And: "caller" has allowance of "allowance" from "aggrievedUser"
        vm.prank(aggrievedUser);
        recoveryControllerExtension.approve(caller, allowance);

        // When: "caller" transfers "amount" from "aggrievedUser" to "to".
        // Then: Transaction should revert with "NoTransfersAllowed".
        vm.prank(caller);
        vm.expectRevert(NoTransfersAllowed.selector);
        recoveryControllerExtension.transferFrom(aggrievedUser, to, amount);
    }
}
