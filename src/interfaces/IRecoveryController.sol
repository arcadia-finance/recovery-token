/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

interface IRecoveryController {
    function RECOVERY_TOKEN() external view returns (address);

    function UNDERLYING_TOKEN() external view returns (address);
}
