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
    uint256 internal constant BATCH_SIZE = 178;

    function run() external {
        (uint256[] memory amounts, address[] memory tos) = getMintData();

        // Split arrays in smaller batches to sign in multiple txs.
        uint256 length;
        uint256[] memory amounts_;
        address[] memory tos_;
        for (uint256 i; i < amounts.length; i += BATCH_SIZE) {
            length = i + BATCH_SIZE > amounts.length ? amounts.length - i : BATCH_SIZE;
            emit log_named_uint("length", length);

            amounts_ = new uint256[](length);
            tos_ = new address[](length);

            for (uint256 j; j < length; j++) {
                amounts_[j] = amounts[i + j];
                tos_[j] = tos[i + j];
            }

            addToBatch(
                SAFE, address(recoveryController), abi.encodeCall(recoveryController.batchMint, (tos_, amounts_))
            );

            // Create and write away batched transaction data to be signed with Safe.
            vm.writeLine(PATH, vm.toString(createBatchedData(SAFE)));
        }
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
