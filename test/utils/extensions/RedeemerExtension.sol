/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Redeemer } from "../../../src/Redeemer.sol";

contract RedeemerExtension is Redeemer {
    constructor(address owner_, address recoveryController, address treasury_)
        Redeemer(owner_, recoveryController, treasury_)
    { }

    function setRedeemed(bytes32 merkleRoot_, address user, uint256 redeemed_) external {
        redeemed[merkleRoot_][user] = redeemed_;
    }
}
