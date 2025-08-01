/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryController } from "../../../src/RecoveryController.sol";

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
