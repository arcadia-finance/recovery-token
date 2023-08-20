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
 * both if assets are redeemed via legal means, or if the lost assets are redeemed via other means..
 * In the second situation the underlying assets will be distributed pro-rata to all holders of
 * Wrapped Recovery Tokens in discrete batches.
 * @dev Recovery Tokens can be redeemed one-to-one for Underlying Tokens.
 * @dev Recovery Tokens will only be eligible for redemption to Underlying Tokens after they are
 * deposited (wrapped) in this Recovery contract. It uses a modification of the ERC20 standard (non-transferrable)
 * to do the accounting of deposited Recovery Token Balances.
 */
contract RecoveryController is ERC20, Owned {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    // Bool indicating if the contract is activated or not.
    bool public active;

    // The growth of Underlying Tokens redeemed per Wrapped Recovery Token for the entire life of the contract.
    uint256 public redeemablePerRTokenGlobal;

    // The unit (10^decimals) of the Underlying Token and the Recovery Token.
    uint256 internal immutable unit;

    // The contract address of the Underlying Token.
    address internal immutable underlying;

    // Map tokenHolder => Growth of Underlying Tokens redeemed per Wrapped Recovery Token at the owner last interaction.
    mapping(address => uint256) internal redeemablePerRTokenLast;
    // Map tokenHolder => Amount of Recovery Tokens redeemed for Underlying Tokens.
    mapping(address => uint256) public redeemed;

    // The (unwrapped) Recovery Token contract.
    RecoveryToken public immutable recoveryToken;

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
        require(active, "NOT_ACTIVE");

        _;
    }

    /**
     * @dev Throws if the contract is active.
     */
    modifier notActive() {
        require(!active, "ACTIVE");

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
                        ACTIVATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets contract to active.
     * @dev After the contract is active, token holders can withdraw, deposit and interact with the contract,
     * and no new recoveryTokens can be minted.
     */
    function activate() external onlyOwner {
        active = true;
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
                        RECOVERY TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits the underlying assets to this contract.
     * Deposited assets become redeemable pro-rata by the Wrapped Recovery Token Holders.
     * @param amount The amount of underlying tokens deposited.
     */
    function depositUnderlying(uint256 amount) external isActive {
        _distributeUnderlying(amount);
        ERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Deposits (wraps) Recovery Tokens.
     * @param amount The non-redeemed rTokens deposited.
     * @dev Holders of Recovery Tokens need to deposit the tokens in this contract before
     * they can redeem the Recovery Tokens for redeemed Underlying Tokens.
     */
    function depositRecoveryTokens(uint256 amount) external isActive {
        // Cache token balances.
        uint256 initialBalance = balanceOf[msg.sender];
        uint256 redeemedLast;
        uint256 redeemable;

        // recoveryToken is a trusted contract.
        recoveryToken.transferFrom(msg.sender, address(this), amount);

        if (initialBalance > 0) {
            redeemedLast = redeemed[msg.sender];
            // Calculate the redeemable underlying tokens since the last redemption.
            redeemable =
                initialBalance.mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[msg.sender], 10e18);
        }

        if (initialBalance + amount - redeemedLast <= redeemable) {
            // Updated balance of redeemed Underlying Tokens exceed the non-redeemed rTokens.
            // Close the position and distribute the surplus to other rToken-Holders.
            _closeRecoveredPosition(msg.sender);
            uint256 surplus = redeemedLast + redeemable - initialBalance - amount;
            _distributeUnderlying(surplus);
        } else {
            // Update accounting for total redeemed Underlying Tokens.
            redeemed[msg.sender] = redeemedLast + redeemable;
            redeemablePerRTokenLast[msg.sender] = redeemablePerRTokenGlobal;

            // Update accounting for newly deposited rTokens.
            _mint(msg.sender, amount);
        }

        // Reentrancy: Transfer the Underlying Tokens after logic.
        _redeemUnderlying(msg.sender, redeemable);
    }

    /**
     * @notice Withdraws (unwraps) Recovery Tokens.
     * @param amount The non-redeemed rTokens withdrawn.
     * @dev Holders of Recovery Tokens need to deposit the tokens in this contract before
     * they can redeem the Recovery Tokens for redeemed Underlying Tokens.
     */
    function withdrawRecoveryTokens(uint256 amount) external isActive {
        // Cache token balances.
        uint256 initialBalance = balanceOf[msg.sender];
        uint256 redeemedLast = redeemed[msg.sender];

        // Calculate the redeemable underlying tokens since the last redemption.
        uint256 redeemable =
            initialBalance.mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[msg.sender], 10e18);

        if (initialBalance - redeemedLast <= redeemable) {
            // Updated balance of redeemed Underlying Tokens, even without withdrawing rTokens,
            // exceeds the non-redeemed rTokens.
            // Close the position, distribute the surplus to other rToken-Holders and no rTokens will be withdrawn.
            _closeRecoveredPosition(msg.sender);
            uint256 surplus = redeemedLast + redeemable - initialBalance;
            redeemable = initialBalance - redeemedLast;
            _distributeUnderlying(surplus);
        } else {
            if (initialBalance - redeemedLast <= redeemable + amount) {
                // Updated balance of redeemed Underlying Tokens would exceed the non-redeemed rTokens
                // after withdrawing rTokens,.
                // Close the position, and withdraw the remaining rTokens.
                _closeRecoveredPosition(msg.sender);
                amount = initialBalance - redeemedLast - redeemable;
            } else {
                // Update accounting for total redeemed Underlying Tokens.
                redeemed[msg.sender] = redeemedLast + redeemable;
                redeemablePerRTokenLast[msg.sender] = redeemablePerRTokenGlobal;

                // Update accounting for withdrawn rTokens.
                _burn(msg.sender, amount);
            }

            // Withdraw the Recovery Tokens to the owner.
            recoveryToken.transfer(msg.sender, amount);
        }

        // Reentrancy: Transfer the Underlying Tokens after logic.
        _redeemUnderlying(msg.sender, redeemable);
    }

    /**
     * @notice Redeems Recovery Tokens for Underlying Tokens.
     * @param owner_ The owner of the wrapped Recovery Tokens.
     * @dev Everyone can call the redeem function for any address.
     */
    function redeemUnderlying(address owner_) external isActive {
        // Cache token balances.
        uint256 initialBalance = balanceOf[owner_];
        uint256 redeemedLast = redeemed[owner_];

        // Calculate the redeemable underlying tokens since the last redemption.
        uint256 redeemable =
            initialBalance.mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[owner_], 10e18);

        if (initialBalance - redeemedLast <= redeemable) {
            // Updated balance of redeemed Underlying Tokens exceed the non-redeemed rTokens.
            // Close the position.
            _closeRecoveredPosition(owner_);
            uint256 surplus = redeemedLast + redeemable - initialBalance;
            redeemable = initialBalance - redeemedLast;
            // Distribute the surplus to other rToken-Holders.
            if (totalSupply != 0) {
                _distributeUnderlying(surplus);
            } else {
                // All positions are recovered, send any remaining funds back to owner.
                ERC20(underlying).safeTransfer(owner, ERC20(underlying).balanceOf(address(this)) - redeemable);
            }
        } else {
            // Update accounting for total redeemed Underlying Tokens.
            redeemed[owner_] = redeemedLast + redeemable;
            redeemablePerRTokenLast[owner_] = redeemablePerRTokenGlobal;
        }

        // Reentrancy: Transfer the Underlying Tokens after logic.
        _redeemUnderlying(owner_, redeemable);
    }

    /**
     * @notice Returns the current maximum amount of Recovery Tokens that can be redeemed for Underlying Tokens.
     * @param owner_ The owner of the wrapped Recovery Tokens.
     */
    function maxRedeemable(address owner_) public view returns (uint256 redeemable) {
        // No need to check if contract is active, since depositUnderlying() reverts when inactive.

        // Calculate the redeemable underlying tokens since the last redemption.
        redeemable = balanceOf[owner_].mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[owner_], 10e18);

        // Minimum of the redeemable amount of underlying tokens and non-redeemed rTokens.
        redeemable =
            balanceOf[owner_] - redeemed[owner_] >= redeemable ? redeemable : balanceOf[owner_] - redeemed[owner_];
    }

    /**
     * @notice Returns the amount of Recovery Tokens that can be redeemed for Underlying Tokens without taking into account restrictions.
     * @param owner_ The owner of the wrapped Recovery Tokens.
     */
    function previewRedeemable(address owner_) public view returns (uint256 redeemable) {
        // Calculate the redeemable underlying tokens since the last redemption.
        redeemable = balanceOf[owner_].mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[owner_], 10e18);
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
     * @param owner_ The owner of the fully recovered position.
     */
    function _closeRecoveredPosition(address owner_) internal {
        redeemed[owner_] = 0;
        redeemablePerRTokenLast[owner_] = 0;
        _burn(owner_, balanceOf[owner_]);
    }

    /**
     * @notice Calculates and updates the growth of Underlying Tokens redeemed per Wrapped Recovery Token.
     * @param amount The amount of redeemed Underlying Tokens.
     */
    function _distributeUnderlying(uint256 amount) internal {
        redeemablePerRTokenGlobal += amount.mulDivDown(10e18, totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT TERMINATION
    //////////////////////////////////////////////////////////////*/

    function initiateTermination() external onlyOwner {}

    function executeTermination() external onlyOwner {}
}
