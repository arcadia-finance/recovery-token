// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";
import {FixedPointMathLib} from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {RecoveryToken} from "./RecoveryToken.sol";

/**
 * @title Recovery Tokens.
 * @author Pragma Labs
 * @notice Handles the accounting and redemption of Recovery Tokens for Underlying Tokens,
 * both if assets are recovered via legal means, or if the lost assets are recovered via other means..
 * In the second situation the underlying assets will be distributed pro-rata to all holders of
 * Wrapped Recovery Tokens in discrete batches.
 * @dev Recovery Tokens can be redeemed one-to-one for Underlying Tokens.
 * @dev Recovery Tokens will only be eligible for redemption to Underlying Tokens after they are
 * deposited (wrapped) in this Recovery contract. It uses a modification of the ERC20 standard (non-transferrable)
 * to do the accounting of deposited Recovery Token Balances.
 */
contract IRecoveryController is ERC20, Owned {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    // Bool indicating if the contract is activated or not.
    bool public active;

    // The growth of Underlying Tokens recovered per Wrapped Recovery Token for the entire life of the contract.
    uint256 public recoveryPerRTokenGlobal;
    // The unit (10^decimals) of the Underlying Token and the Recovery Token.
    uint256 internal immutable unit;

    // The contract address of the Underlying Token.
    address internal immutable underlying;

    // Map owner => Growth of Underlying Tokens recovered per Wrapped Recovery Token at the owner last interaction.
    mapping(address => uint256) internal recoveryPerRTokenLast;
    // Map owner => Amount of Recovery Tokens redeemed for Underlying Tokens.
    mapping(address => uint256) public recovered;

    // The (unwrapped) Recovery Token contract.
    RecoveryToken internal immutable recoveryToken;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAllowed();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Throws if the contract is not active.
     */
    modifier isActive() {
        require(active, "NOT ACTIVE");

        _;
    }

    /**
     * @dev Throws if the contract is active.
     */
    modifier notActive() {
        require(!active, "NOT ACTIVE");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param underlying_ The contract address of the Underlying Token.
     */
    constructor(address underlying_)
        ERC20("Wrapped Arcadia Recovery Tokens", "wART", ERC20(underlying_).decimals())
        Owned(msg.sender)
    {
        underlying = underlying_;
        unit = 10 ** decimals;
        recoveryToken = new RecoveryToken(msg.sender, address(this), decimals);
    }

    /*//////////////////////////////////////////////////////////////
                        RECOVERY TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits the underlying assets to this contract.
     * Deposited assets become recoverable pro-rata by the Wrapped Recovery Token Holders.
     * @param amount The amount of underlying tokens deposited.
     */
    function depositUnderlying(uint256 amount) external {
        _distributeUnderlying(amount);
        ERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Deposits (wraps) Recovery Tokens.
     * @param amount The non-redeemed rTokens deposited.
     * @dev Holders of Recovery Tokens need to deposit the tokens in this contract before
     * they can redeem the Recovery Tokens for recovered Underlying Tokens.
     */
    function depositRecoveryTokens(uint256 amount) external isActive {
        // Cache token balances.
        uint256 initialBalance = balanceOf[msg.sender];
        uint256 recoveredLast;
        uint256 recoverable;

        // recoveryToken is a trusted contract.
        recoveryToken.transferFrom(msg.sender, address(this), amount);

        if (initialBalance > 0) {
            recoveredLast = recovered[msg.sender];
            // Calculate the recoverable underlying tokens since the last redemption.
            recoverable = initialBalance * (recoveryPerRTokenGlobal - recoveryPerRTokenLast[msg.sender]);
        }

        if (initialBalance + amount <= recoveredLast + recoverable) {
            // Updated balance of recovered Underlying Tokens exceed the non-redeemed rTokens.
            // Close the position and distribute the surplus to other rToken-Holders.
            _closeRecoveredPosition(msg.sender);
            uint256 surplus = recoveredLast + recoverable - initialBalance - amount;
            _distributeUnderlying(surplus);
        } else {
            // Update accounting for total recovered Underlying Tokens.
            recovered[msg.sender] = recoveredLast + recoverable;
            recoveryPerRTokenLast[msg.sender] = recoveryPerRTokenGlobal;

            // Update accounting for newly deposited rTokens.
            _mint(msg.sender, amount);
        }

        // Reentrancy: Transfer the Underlying Tokens after logic.
        _redeemUnderlying(msg.sender, recoverable);
    }

    /**
     * @notice Withdraws (unwraps) Recovery Tokens.
     * @param amount The non-redeemed rTokens withdrawn.
     * @dev Holders of Recovery Tokens need to deposit the tokens in this contract before
     * they can redeem the Recovery Tokens for recovered Underlying Tokens.
     */
    function withdrawRecoveryTokens(uint256 amount) external isActive {
        // Cache token balances.
        uint256 initialBalance = balanceOf[msg.sender];
        uint256 recoveredLast = recovered[msg.sender];

        // Calculate the recoverable underlying tokens since the last redemption.
        uint256 recoverable = initialBalance * (recoveryPerRTokenGlobal - recoveryPerRTokenLast[msg.sender]);

        if (initialBalance <= recoveredLast + recoverable) {
            // Updated balance of recovered Underlying Tokens, even without withdrawing rTokens,
            // exceeds the non-redeemed rTokens.
            // Close the position, distribute the surplus to other rToken-Holders and no rTokens will be withdrawn.
            _closeRecoveredPosition(msg.sender);
            uint256 surplus = recoveredLast + recoverable - initialBalance;
            recoverable = initialBalance - recoveredLast;
            _distributeUnderlying(surplus);
        } else {
            if (initialBalance <= recoveredLast + recoverable + amount) {
                // Updated balance of recovered Underlying Tokens would exceed the non-redeemed rTokens
                // after withdrawing rTokens,.
                // Close the position, and withdraw the remaining rTokens.
                _closeRecoveredPosition(msg.sender);
                amount = initialBalance - recoveredLast - recoverable;
            } else {
                // Update accounting for total recovered Underlying Tokens.
                recovered[msg.sender] = recoveredLast + recoverable;
                recoveryPerRTokenLast[msg.sender] = recoveryPerRTokenGlobal;

                // Update accounting for withdrawn rTokens.
                _burn(msg.sender, amount);
            }

            // Withdraw the Recovery Tokens to the owner.
            recoveryToken.transfer(msg.sender, amount);
        }

        // Reentrancy: Transfer the Underlying Tokens after logic.
        _redeemUnderlying(msg.sender, recoverable);
    }

    /**
     * @notice Redeems Recovery Tokens for Underlying Tokens.
     * @param owner_ The owner of the wrapped Recovery Tokens.
     * @dev Everyone can call the redeem function for any address.
     */
    function redeemUnderlying(address owner_) external isActive {
        // Cache token balances.
        uint256 initialBalance = balanceOf[owner_];
        uint256 recoveredLast = recovered[owner_];

        // Calculate the recoverable underlying tokens since the last redemption.
        uint256 recoverable = initialBalance * (recoveryPerRTokenGlobal - recoveryPerRTokenLast[owner_]);

        if (initialBalance <= recoveredLast + recoverable) {
            // Updated balance of recovered Underlying Tokens exceed the non-redeemed rTokens.
            // Close the position and distribute the surplus to other rToken-Holders.
            _closeRecoveredPosition(owner_);
            uint256 surplus = recoveredLast + recoverable - initialBalance;
            recoverable = initialBalance - recoveredLast;
            _distributeUnderlying(surplus);
        } else {
            // Update accounting for total recovered Underlying Tokens.
            recovered[owner_] = recoveredLast + recoverable;
            recoveryPerRTokenLast[owner_] = recoveryPerRTokenGlobal;
        }

        // Reentrancy: Transfer the Underlying Tokens after logic.
        _redeemUnderlying(owner_, recoverable);
    }

    /**
     * @notice View function returns the recoverable balance.
     * @param owner_ The owner of the wrapped Recovery Tokens.
     */
    function recoverableOf(address owner_) public view returns (uint256 recoverable) {
        // Calculate the recoverable underlying tokens since the last redemption.
        recoverable = balanceOf[owner_] * (recoveryPerRTokenGlobal - recoveryPerRTokenLast[owner_]);

        // Minimum of the recoverable amount of underlying tokens and non-redeemed rTokens.
        recoverable =
            balanceOf[owner_] >= recoverable + recovered[owner_] ? recoverable : balanceOf[owner_] - recovered[owner_];
    }

    /**
     * @notice Logic to redeem Recovery Tokens for Underlying Tokens.
     * @param to The receiver of the Underlying Tokens.
     * @param amount The amount of tokens redeemed.
     * @dev Recovery Tokens are redeemed one-to-one for Underlying Tokens.
     */
    function _redeemUnderlying(address to, uint256 amount) internal {
        // Burn the redeemed recovery tokens.
        recoveryToken.burn(amount);
        // Send equal amount of underlying assets.
        // Reentrancy: Transfer the Underlying Tokens after logic.
        ERC20(underlying).safeTransfer(to, amount);
    }

    /**
     * @notice Logic to close a fully recovered position.
     * @param owner_ The owner of the recovered Recovery Tokens.
     */
    function _closeRecoveredPosition(address owner_) internal {
        recovered[owner_] = 0;
        recoveryPerRTokenLast[owner_] = 0;
        _burn(owner_, balanceOf[owner_]);
    }

    /**
     * @notice Calculates and updates the growth of Underlying Tokens recovered per Wrapped Recovery Token.
     * @param amount The amount of recovered Underlying Tokens.
     */
    function _distributeUnderlying(uint256 amount) internal {
        recoveryPerRTokenGlobal += amount.mulDivDown(unit, totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Modification of the ERC-20 transfer implementation.
     * @dev No transfer allowed.
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert NotAllowed();
    }

    /**
     * @notice Modification of the ERC-20 transferFrom implementation.
     * @dev No transferFrom allowed.
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert NotAllowed();
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints Wrapped Recovery Tokens.
     * @param to The address that receives the minted tokens.
     * @param amount The amount of tokens minted.
     * @dev Mints an equal amount of (unwrapped) Recovery Tokens.
     */
    function mint(address to, uint256 amount) external onlyOwner notActive {
        _mint(to, amount);
        recoveryToken.mint(amount);
    }

    /**
     * @notice Batch mints Wrapped Recovery Tokens.
     * @param tos Array with addresses that receives the minted tokens.
     * @param amounts Array with amounts of tokens minted.
     * @dev Mints an amount of (unwrapped) Recovery Tokens equal to sum of all amounts.
     */
    function batchMint(address[] calldata tos, uint256[] calldata amounts) external onlyOwner notActive {
        uint256 length = tos.length;
        uint256 totalAmount;

        require(length == amounts.length, "LENGTH_MISMATCH");

        uint256 amount;
        for (uint256 i; i < length;) {
            amount = amounts[i];
            _mint(tos[i], amount);

            unchecked {
                ++i;
                totalAmount += amount;
            }
        }

        recoveryToken.mint(totalAmount);
    }

    /**
     * @notice Burns Wrapped Recovery Tokens.
     * @param from The address from which the tokens are burned.
     * @param amount The amount of tokens burned.
     * @dev Burns an equal amount of (unwrapped) Recovery Tokens.
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
        recoveryToken.burn(amount);
    }

    /**
     * @notice Batch burns Wrapped Recovery Tokens.
     * @param tos Array with addresses from which the tokens are burned.
     * @param amounts Array with amounts of tokens burned.
     * @dev Burns an amount of (unwrapped) Recovery Tokens equal to sum of all amounts.
     */
    function batchBurn(address[] calldata tos, uint256[] calldata amounts) external onlyOwner {
        uint256 length = tos.length;
        uint256 totalAmount;

        require(length == amounts.length, "LENGTH_MISMATCH");

        uint256 amount;
        for (uint256 i; i < length;) {
            amount = amounts[i];
            _burn(tos[i], amount);

            unchecked {
                ++i;
                totalAmount += amount;
            }
        }

        recoveryToken.burn(totalAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT TERMINATION
    //////////////////////////////////////////////////////////////*/

    function initiateTermination() external onlyOwner {}

    function executeTermination() external onlyOwner {}
}
