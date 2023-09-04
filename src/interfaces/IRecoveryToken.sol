/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IRecoveryToken {
    /**
     * @notice Mints Recovery Tokens.
     * @param amount The amount of Recovery Tokens minted.
     */
    function mint(uint256 amount) external;

    /**
     * @notice Burns Recovery Tokens.
     * @param amount The amount of Recovery Tokens burned.
     */
    function burn(uint256 amount) external;
}
