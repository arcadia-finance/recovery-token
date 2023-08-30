/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IRecoveryToken {
    function mint(uint256 amount) external;

    function burn(uint256 amount) external;
}
