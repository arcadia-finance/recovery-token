/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Base_Script } from "./Base.s.sol";
import { Safes } from "./utils/Constants.sol";
import { stdJson } from "../lib/forge-std/src/StdJson.sol";

contract BatchMint is Base_Script {
    using stdJson for string;

    address internal SAFE = Safes.OWNER;

    function run() external {
        (uint256[] memory amounts, address[] memory tos) = getMintData();

        // Mint Recovery Tokens.
        addToBatch(SAFE, address(recoveryController), abi.encodeCall(recoveryController.batchMint, (tos, amounts)));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }

    function getMintData() internal view returns (uint256[] memory amounts, address[] memory tos) {
        // Read Json.
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/mint_data.json");
        string memory json = vm.readFile(path);

        // Parse Json.
        amounts = json.readUintArray(".amounts");
        tos = json.readAddressArray(".tos");
    }
}
