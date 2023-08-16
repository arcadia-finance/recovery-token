/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {RecoveryController} from "../../src/RecoveryController.sol";

contract RecoveryControllerExtension is RecoveryController {
    constructor(address underlying_) RecoveryController(underlying_) {}

    function getRecoveryToken() public view returns (address recoveryToken_) {
        recoveryToken_ = address(recoveryToken);
    }
}
