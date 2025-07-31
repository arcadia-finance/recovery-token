/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { FeeClaimer } from "../../../src/FeeClaimer.sol";

contract FeeClaimerExtension is FeeClaimer {
    constructor(address owner_, address recoveryController, address treasury_)
        FeeClaimer(owner_, recoveryController, treasury_)
    { }

    function setClaimed(bytes32 merkleRoot_, address user, uint256 claimed_) external {
        claimed[merkleRoot_][user] = claimed_;
    }
}
