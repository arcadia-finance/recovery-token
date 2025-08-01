/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Base_Script } from "./Base.s.sol";
import { RecoveryController } from "../src/RecoveryController.sol";
import { Safes } from "./utils/Constants.sol";

contract Activate is Base_Script {
    address internal SAFE = Safes.OWNER;

    function run() external {
        // Activate Recovery Tokens.
        addToBatch(SAFE, address(recoveryController), abi.encodeCall(recoveryController.activate, ()));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
