/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";

/**
 * @title Arcadia Recovery Tokens.
 * @author Pragma Labs
 * @notice ERC20 contract for the accounting of the Recovery of lost Underlying Tokens.
 * @dev The one-to-one redemption of Recovery Tokens for Underlying Tokens,
 * is handled by the Recovery Controller.
 */
contract RecoveryToken is ERC20, Owned {
    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    // The contract address of the Recovery Controller.
    address public immutable recoveryController;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    // Thrown when 'msg.sender" is not the 'recoveryController'.
    error NotRecoveryController();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Throws if called by any account other than the Recovery Controller.
     */
    modifier onlyRecoveryController() {
        if (msg.sender != recoveryController) revert NotRecoveryController();

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner_ The address of owner of the contract.
     * @param recoveryController_ The contract address of the Recovery Controller.
     * @param decimals_ Must be identical to decimals of the Underlying Token.
     */
    constructor(address owner_, address recoveryController_, uint8 decimals_)
        ERC20("Arcadia Recovery Token", "ART", decimals_)
        Owned(owner_)
    {
        recoveryController = recoveryController_;
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints Recovery Tokens.
     * @param amount The amount of Recovery Tokens minted.
     * @dev Only the Recovery Controller can mint tokens before it is activated.
     */
    function mint(uint256 amount) external onlyRecoveryController {
        _mint(msg.sender, amount);
    }

    /**
     * @notice Burns Recovery Tokens.
     * @param amount The amount of Recovery Tokens burned.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burns Recovery Tokens.
     * @param from The address from which the tokens are burned.
     * @param amount The amount of Recovery Tokens burned.
     */
    function burn(address from, uint256 amount) external onlyRecoveryController {
        _burn(from, amount);
    }
}
