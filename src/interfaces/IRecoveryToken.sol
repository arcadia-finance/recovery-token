/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

interface IRecoveryToken {
    /**
     * @notice Burns Recovery Tokens.
     * @param amount The amount of Recovery Tokens burned.
     */
    function burn(uint256 amount) external;
}
