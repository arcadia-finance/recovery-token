/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { RecoveryController } from "../src/RecoveryController.sol";
import { Script } from "../lib/forge-std/src/Script.sol";
import { stdJson } from "../lib/forge-std/src/StdJson.sol";

contract DeployRecoveryContracts is Script {
    using stdJson for string;

    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    address internal constant USDC_ADDRESS = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    ///////////////////////////////////////////////////////////////*/

    uint256 internal broadcasterPrivateKey;

    /*///////////////////////////////////////////////////////////////
                            CONTRACTS
    ///////////////////////////////////////////////////////////////*/

    RecoveryController internal recoveryController;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    constructor() {
        broadcasterPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_OPTIMISM");
    }

    /*///////////////////////////////////////////////////////////////
                        RUN DEPLOY SCRIPT
    ///////////////////////////////////////////////////////////////*/

    function run() external {
        // Deploy Recovery Contracts.
        vm.broadcast(broadcasterPrivateKey);
        recoveryController = new RecoveryController(USDC_ADDRESS);

        // Mint Recovery Tokens.
        (uint256[] memory amounts, address[] memory tos) = getMintData();
        vm.broadcast(broadcasterPrivateKey);
        recoveryController.batchMint(tos, amounts);
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
