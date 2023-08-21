/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {RecoveryController} from "../../src/RecoveryController.sol";
import {RecoveryToken} from "../../src/RecoveryToken.sol";

contract RecoveryControllerExtension is RecoveryController {
    constructor(address underlying_) RecoveryController(underlying_) {}

    function getRecoveryToken() public view returns (address recoveryToken_) {
        recoveryToken_ = address(recoveryToken);
    }
}

contract RecoveryTokenExtension is RecoveryToken {
    constructor(address owner_, address recoveryController_, uint8 decimals_)
        RecoveryToken(owner_, recoveryController_, decimals_)
    {}

    function getRecoveryController() public view returns (address recoveryController_) {
        recoveryController_ = recoveryController;
    }
}
