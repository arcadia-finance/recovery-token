/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryToken } from "../../../src/RecoveryToken.sol";

contract RecoveryTokenExtension is RecoveryToken {
    constructor(address recoveryController_, uint8 decimals_) RecoveryToken(recoveryController_, decimals_) { }

    function getRecoveryController() public view returns (address recoveryController_) {
        recoveryController_ = recoveryController;
    }
}
