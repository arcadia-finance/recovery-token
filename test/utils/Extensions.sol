/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import {RecoveryController} from "../../src/RecoveryController.sol";
import {RecoveryToken} from "../../src/RecoveryToken.sol";

contract RecoveryControllerExtension is RecoveryController {
    constructor(address underlying_) RecoveryController(underlying_) {}

    function getUnderlying() public view returns (address underlying_) {
        underlying_ = address(underlying);
    }

    function setTerminationTimestamp(uint32 terminationTimestamp_) public {
        terminationTimestamp = terminationTimestamp_;
    }

    function distributeUnderlying(uint256 amount) public {
        _distributeUnderlying(amount);
    }

    function getRedeemablePerRTokenLast(address tokenHolder) public view returns (uint256 redeemablePerRTokenLast_) {
        redeemablePerRTokenLast_ = redeemablePerRTokenLast[tokenHolder];
    }

    function setRedeemablePerRTokenLast(address tokenHolder, uint256 redeemablePerRTokenLast_) public {
        redeemablePerRTokenLast[tokenHolder] = redeemablePerRTokenLast_;
    }

    function setActive(bool active_) public {
        active = active_;
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
