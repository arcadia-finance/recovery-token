/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Claimer, Assets, Deployers, Safes } from "./utils/Constants.sol";
import { FeeClaimer } from "../src/FeeClaimer.sol";
import { Base_Script } from "./Base.s.sol";
import { RecoveryController } from "../src/RecoveryController.sol";

contract DeployRecoveryContracts is Base_Script {
    function run() external {
        require(vm.addr(deployer) == Deployers.ARCADIA, "Wrong deployer.");

        // Deploy Recovery Contracts.
        vm.startBroadcast(deployer);
        recoveryController = new RecoveryController(Safes.OWNER, Assets.USDC);

        feeClaimer = new FeeClaimer(Safes.OWNER, address(recoveryController), Claimer.TREASURY);
    }
}
