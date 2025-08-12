/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Assets, Deployers, FeeRedeemer, Safes } from "./utils/Constants.sol";
import { Base_Script } from "./Base.s.sol";
import { RecoveryController } from "../src/RecoveryController.sol";
import { Redeemer } from "../src/Redeemer.sol";

contract DeployRecoveryContracts is Base_Script {
    function run() external {
        require(vm.addr(deployer) == Deployers.ARCADIA, "Wrong deployer.");

        // Deploy Recovery Contracts.
        vm.startBroadcast(deployer);
        recoveryController = new RecoveryController(Safes.OWNER, Assets.USDC);

        redeemer = new Redeemer(Safes.OWNER, address(recoveryController), FeeRedeemer.TREASURY);
    }
}
