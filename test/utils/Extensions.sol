/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryController } from "../../src/RecoveryController.sol";
import { RecoveryToken } from "../../src/RecoveryToken.sol";

/**
 * @notice Extension contracts allow access to internal functions and the creation of getters and setters for all variables.
 * This allows free modification of the state for both the test contracts as integrations with third party contracts.
 * As such the complete space of possible state configurations can be tested.
 */
contract RecoveryControllerExtension is RecoveryController {
    constructor(address owner_, address underlying_) RecoveryController(owner_, underlying_) { }

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
    constructor(address recoveryController_, uint8 decimals_) RecoveryToken(recoveryController_, decimals_) { }

    function getRecoveryController() public view returns (address recoveryController_) {
        recoveryController_ = recoveryController;
    }
}
