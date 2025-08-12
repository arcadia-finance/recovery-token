/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.30;

import { Arcadia } from "./utils/Constants.sol";
import { Redeemer } from "../src/Redeemer.sol";
import { RecoveryController } from "../src/RecoveryController.sol";
import { RecoveryToken } from "../src/RecoveryToken.sol";
import { SafeTransactionBuilder } from "./utils/SafeTransactionBuilder.sol";
import { Test } from "../lib/forge-std/src/Test.sol";

abstract contract Base_Script is Test, SafeTransactionBuilder {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_DEPLOYER");

    Redeemer internal redeemer = Redeemer(Arcadia.REDEEMER);
    RecoveryController internal recoveryController = RecoveryController(Arcadia.RECOVERY_CONTROLLER);
    RecoveryToken internal recoveryToken = RecoveryToken(Arcadia.RECOVERY_TOKEN);
}
