/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

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
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Minimum cooldown period between the termination initiation and finalisation.
    uint256 internal constant COOLDOWN_PERIOD = 1 weeks;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    // The contract address of the Underlying Token.
    address internal immutable underlying;

    // The (unwrapped) Recovery Token contract.
    RecoveryToken public immutable recoveryToken;

    // Bool indicating if the contract is activated or not.
    bool public active;

    // Timestamp that the termination of the contract is initiated.
    uint32 public terminationTimestamp;

    // The growth of Underlying Tokens redeemed per Wrapped Recovery Token for the entire life of the contract.
    uint256 public redeemablePerRTokenGlobal;

    // Map tokenHolder => Growth of Underlying Tokens redeemed per Wrapped Recovery Token at the owner last interaction.
    mapping(address => uint256) public redeemablePerRTokenLast;
    // Map tokenHolder => Amount of Recovery Tokens redeemed for Underlying Tokens.
    mapping(address => uint256) public redeemed;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Emitted when a value for the activity of the Controller is set.
     * @param active Bool indicating if the contract is activated or not.
     */
    event ActivationSet(bool active);

    /**
     * @notice Emitted when the termination of the Controller is initiated.
     * @param timestamp The timestamp when the termination of the contract is initiated.
     */
    event TerminationInitiated(uint32 timestamp);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    // Thrown if the Contract is terminated.
    error ControllerTerminated();

    // Thrown if the Contract is not active.
    error NotActive();

    // Thrown if the Contract is active.
    error Active();

    // Thrown on transfers.
    error NoTransfersAllowed();

    // Thrown if arrays are not equal in length..
    error LengthMismatch();

    // Thrown when trying to deposit zero assets.
    error DepositAmountZero();

    // Thrown when trying to withdraw zero assets.
    error WithdrawAmountZero();

    // Thrown when less time as the cooldown period passed between the termination initiation and finalisation.
    error TerminationCoolDownPeriodNotPassed();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Throws if the contract is not active.
     */
    modifier isActive() {
        if (!active) revert NotActive();

        _;
    }

    /**
     * @dev Throws if the contract is active.
     */
    modifier notActive() {
        if (active) revert Active();

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
        recoveryToken = new RecoveryToken(msg.sender, address(this), decimals);

        emit ActivationSet(false);
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
        if (terminationTimestamp != 0) revert ControllerTerminated();

        active = true;

        emit ActivationSet(true);
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Modification of the ERC-20 transfer implementation.
     * @dev No transfer allowed.
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert NoTransfersAllowed();
    }

    /**
     * @notice Modification of the ERC-20 transferFrom implementation.
     * @dev No transferFrom allowed.
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert NoTransfersAllowed();
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints Wrapped Recovery Tokens.
     * @param to The address that receives the minted tokens.
     * @param amount The amount of tokens minted.
     * @dev Mints an amount of Recovery Tokens to the controller,
     * equal to the minted Wrapped Recovery Tokens.
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
     * @dev Mints an amount of Recovery Tokens to the controller,
     * equal to the sum of all minted Wrapped Recovery Tokens.
     */
    function batchMint(address[] calldata tos, uint256[] calldata amounts) external onlyOwner notActive {
        uint256 length = tos.length;
        uint256 totalAmount;

        if (length != amounts.length) revert LengthMismatch();

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
     * @dev Burns an amount of Recovery Tokens, held by the controller,
     * equal to the burned unredeemed Wrapped Recovery Tokens.
     */
    function burn(address from, uint256 amount) external onlyOwner {
        uint256 openPosition = balanceOf[from] - redeemed[from];

        // Burn the Wrapped Recovery Tokens.
        if (amount >= openPosition) {
            _closePosition(from);
            amount = openPosition;
        } else {
            _burn(from, amount);
        }

        // Burn the corresponding Recovery Tokens held by the controller.
        recoveryToken.burn(amount);
    }

    /**
     * @notice Batch burns Wrapped Recovery Tokens.
     * @param froms Array with addresses from which the tokens are burned.
     * @param amounts Array with amounts of tokens burned.
     * @dev Burns an amount of Recovery Tokens, held by the controller,
     * equal to the sum of all burned unredeemed Wrapped Recovery Tokens.
     */
    function batchBurn(address[] calldata froms, uint256[] calldata amounts) external onlyOwner {
        uint256 length = froms.length;

        if (length != amounts.length) revert LengthMismatch();

        address from;
        uint256 openPosition;
        uint256 amount;
        uint256 totalAmount;
        for (uint256 i; i < length;) {
            from = froms[i];
            openPosition = balanceOf[from] - redeemed[from];
            amount = amounts[i];

            // Burn the Wrapped Recovery Tokens.
            if (amount >= openPosition) {
                _closePosition(from);
                amount = openPosition;
            } else {
                _burn(from, amount);
            }

            unchecked {
                ++i;
                totalAmount += amount;
            }
        }

        // Burn the corresponding Recovery Tokens held by the controller.
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
        if (amount == 0) revert DepositAmountZero();

        _distributeUnderlying(amount);
        ERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
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
        uint256 openPosition = initialBalance - redeemedLast;

        // Calculate the redeemable underlying tokens since the last redemption.
        uint256 redeemable =
            initialBalance.mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[owner_], 1e18);

        if (openPosition <= redeemable) {
            // Updated balance of redeemed Underlying Tokens exceeds the non-redeemed rTokens.
            // -> Close the position and settle surplus rTokens.
            _closePosition(owner_);
            uint256 surplus = redeemable - openPosition;
            redeemable = openPosition;
            _settleSurplus(surplus, redeemable);
        } else {
            // Position not fully recovered, update accounting for total redeemed Underlying Tokens.
            redeemed[owner_] = redeemedLast + redeemable;
            redeemablePerRTokenLast[owner_] = redeemablePerRTokenGlobal;
        }

        // Reentrancy: Transfer the Underlying Tokens after logic.
        _redeemUnderlying(owner_, redeemable);
    }

    /**
     * @notice Deposits (wraps) Recovery Tokens.
     * @param amount The non-redeemed rTokens deposited.
     * @dev Holders of Recovery Tokens need to deposit the tokens in this contract before
     * they can redeem the Recovery Tokens for redeemed Underlying Tokens.
     */
    function depositRecoveryTokens(uint256 amount) external isActive {
        if (amount == 0) revert DepositAmountZero();

        // Cache token balances.
        uint256 initialBalance = balanceOf[msg.sender];
        uint256 redeemedLast;
        uint256 redeemable;

        // Reentrancy: recoveryToken is a trusted contract without hooks or external calls.
        // Recovery Tokens need to be transferred to Controller before a position can be closed.
        recoveryToken.transferFrom(msg.sender, address(this), amount);

        if (initialBalance != 0) {
            redeemedLast = redeemed[msg.sender];
            // Calculate the redeemable underlying tokens since the last redemption.
            redeemable =
                initialBalance.mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[msg.sender], 1e18);
        }

        uint256 openPosition = initialBalance + amount - redeemedLast;

        if (openPosition <= redeemable) {
            // Updated balance of redeemed Underlying Tokens exceeds the non-redeemed rTokens.
            // Close the position and distribute the surplus to other rToken-Holders.
            _closePosition(msg.sender);
            uint256 surplus = redeemable - openPosition;
            redeemable = openPosition;
            // Settle surplus to other rToken-Holders or the Protocol Owner.
            _settleSurplus(surplus, redeemable);
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
        if (amount == 0) revert WithdrawAmountZero();

        // Cache token balances.
        uint256 initialBalance = balanceOf[msg.sender];
        uint256 redeemedLast = redeemed[msg.sender];
        uint256 openPosition = initialBalance - redeemedLast;

        // Calculate the redeemable underlying tokens since the last redemption.
        uint256 redeemable =
            initialBalance.mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[msg.sender], 1e18);

        if (openPosition <= redeemable) {
            // Updated balance of redeemed Underlying Tokens, even before withdrawing rTokens,
            // exceeds the non-redeemed rTokens.
            // -> Close the position and settle surplus rTokens.
            _closePosition(msg.sender);
            uint256 surplus = redeemable - openPosition;
            redeemable = openPosition;
            // Settle surplus to other rToken-Holders or the Protocol Owner.
            _settleSurplus(surplus, redeemable);
        } else {
            if (openPosition - redeemable <= amount) {
                // Updated balance of redeemed Underlying Tokens, after withdrawing rTokens
                // exceeds the non-redeemed rTokens.
                // -> Close the position and withdraw the remaining rTokens.
                _closePosition(msg.sender);
                amount = openPosition - redeemable;
                // Check if there is surplus to settle to the Protocol Owner.
                _settleSurplus(0, redeemable);
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
     * @notice Returns the current maximum amount of Recovery Tokens that can be redeemed for Underlying Tokens.
     * @param owner_ The owner of the wrapped Recovery Tokens.
     */
    function maxRedeemable(address owner_) public view returns (uint256 redeemable) {
        // Calculate the redeemable underlying tokens since the last redemption.
        redeemable = balanceOf[owner_].mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[owner_], 1e18);

        // Calculate the open position.
        uint256 openPosition = balanceOf[owner_] - redeemed[owner_];

        // Return Minimum.
        redeemable = openPosition <= redeemable ? openPosition : redeemable;
    }

    /**
     * @notice Returns the amount of Recovery Tokens that can be redeemed for Underlying Tokens without taking into account restrictions.
     * @param owner_ The owner of the wrapped Recovery Tokens.
     */
    function previewRedeemable(address owner_) public view returns (uint256 redeemable) {
        // Calculate the redeemable underlying tokens since the last redemption.
        redeemable = balanceOf[owner_].mulDivDown(redeemablePerRTokenGlobal - redeemablePerRTokenLast[owner_], 1e18);
    }

    /**
     * @notice Logic to close a fully recovered position.
     * @param owner_ The owner of the fully recovered position.
     */
    function _closePosition(address owner_) internal {
        redeemed[owner_] = 0;
        redeemablePerRTokenLast[owner_] = 0;
        _burn(owner_, balanceOf[owner_]);
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
     * @notice Logic to settle any surplus Recovery Tokens after a position is closed.
     * @param surplus The amount of surplus Recovery Tokens.
     * @param redeemable The amount of Underlying Tokens that are redeemed.
     */
    function _settleSurplus(uint256 surplus, uint256 redeemable) internal {
        if (totalSupply != 0) {
            // Not all positions are recovered, distribute the surplus to other rToken-Holders.
            _distributeUnderlying(surplus);
        } else {
            // All positions are recovered, send any remaining Underlying Tokens back to the Protocol Owner.
            ERC20(underlying).safeTransfer(owner, ERC20(underlying).balanceOf(address(this)) - redeemable);
        }
    }

    /**
     * @notice Calculates and updates the growth of Underlying Tokens redeemed per Wrapped Recovery Token.
     * @param amount The amount of redeemed Underlying Tokens.
     */
    function _distributeUnderlying(uint256 amount) internal {
        if (amount != 0) redeemablePerRTokenGlobal += amount.mulDivDown(1e18, totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT TERMINATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Starts the termination process.
     * @dev The termination process is a two step process, a fixed 'COOLDOWN_PERIOD' should pass between initiation and finalisation.
     * @dev during the 'COOLDOWN_PERIOD' all Wrapped Recovery Token Holders should claim their redeemable balances.
     */
    function initiateTermination() external onlyOwner {
        terminationTimestamp = uint32(block.timestamp);

        emit TerminationInitiated(uint32(block.timestamp));
    }

    /**
     * @notice Finalises the termination process.
     * @dev The termination process is a two step process, a fixed 'COOLDOWN_PERIOD' should pass between initiation and finalisation.
     * @dev After the 'COOLDOWN_PERIOD' the 'owner' of the Controller can withdraw the remaining balance of Underlying Tokens.
     * When the termination is finalised, the Controller will cease to operate and cannot be restarted.
     */
    function finaliseTermination() external onlyOwner {
        if (terminationTimestamp == 0 || terminationTimestamp + COOLDOWN_PERIOD > uint32(block.timestamp)) {
            revert TerminationCoolDownPeriodNotPassed();
        }

        active = false;

        // Withdraw any remaining Underlying Tokens back to the Protocol Owner.
        ERC20(underlying).safeTransfer(owner, ERC20(underlying).balanceOf(address(this)));

        emit ActivationSet(false);
    }
}
