/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Base_Script } from "./Base.s.sol";
import { Claimer, Safes } from "./utils/Constants.sol";

contract SetMerkleRoot is Base_Script {
    address internal SAFE = Safes.OWNER;

    function run() external {
        // Mint Recovery Tokens.
        addToBatch(SAFE, address(feeClaimer), abi.encodeCall(feeClaimer.setMerkleRoot, (Claimer.ROOT)));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
