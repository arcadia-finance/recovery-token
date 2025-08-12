/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";
import { IRecoveryController } from "./interfaces/IRecoveryController.sol";
import { IRecoveryToken } from "./interfaces/IRecoveryToken.sol";
import { MerkleProofLib } from "../lib/solady/src/utils/MerkleProofLib.sol";
import { Owned } from "../lib/solmate/src/auth/Owned.sol";
import { SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Redeemer.
 * @author Pragma Labs
 * @notice Uses a Merkle tree to efficiently verify redemptions.
 */
contract Redeemer is Owned {
    using SafeTransferLib for ERC20;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Recovery Token.
    address public immutable RECOVERY_TOKEN;

    // The contract address of the Underlying Token in which the redemptions are denominated.
    ERC20 public immutable UNDERLYING_TOKEN;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    // The root of the Merkle tree containing valid redemptions.
    bytes32 public merkleRoot;

    // The contract address of the treasury, holding the underlying tokens.
    address public treasury;

    // A mapping to track per merkle root which users has redeemed how much.
    mapping(bytes32 root => mapping(address user => uint256 amount)) public redeemed;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event MerkleRootSet(bytes32 indexed merkleRoot);
    event Redeemed(bytes32 indexed root, address indexed user, uint256 amount);
    event TreasurySet(address indexed treasury);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error AlreadyRedeemed();
    error InvalidProof();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner_ The address of the Owner.
     * @param recoveryController The contract address of the Recovery Controller.
     * @param treasury_ The address of the treasury.
     */
    constructor(address owner_, address recoveryController, address treasury_) Owned(owner_) {
        RECOVERY_TOKEN = IRecoveryController(recoveryController).RECOVERY_TOKEN();
        UNDERLYING_TOKEN = ERC20(IRecoveryController(recoveryController).UNDERLYING_TOKEN());

        emit TreasurySet(treasury = treasury_);
    }

    /* //////////////////////////////////////////////////////////////
                           OWNER LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets a new root of the Merkle tree.
     * @param merkleRoot_ The new root of the Merkle tree.
     */
    function setMerkleRoot(bytes32 merkleRoot_) external onlyOwner {
        emit MerkleRootSet(merkleRoot = merkleRoot_);
    }

    /**
     * @notice Sets a new treasury.
     * @param treasury_ The address of the treasury.
     */
    function setTreasury(address treasury_) external onlyOwner {
        emit TreasurySet(treasury = treasury_);
    }

    /* //////////////////////////////////////////////////////////////
                            CLAIM LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Redeems Underlying Tokens for eligible users verified by Merkle proof.
     * @param amount The amount of tokens the user wants to redeem.
     * @param maxRedeemable The maximum amount of tokens the user can redeem for the latest Merkle root.
     * @param merkleProofs Array of hashes providing proof of inclusion in the Merkle tree.
     * @dev Treasury has to approve this contract to spend the total redeemable amount of Underlying Tokens.
     * @dev Caller has to approve this contract to spend the redeemable amount of Recovery Tokens.
     */
    function redeem(uint256 amount, uint256 maxRedeemable, bytes32[] calldata merkleProofs) external {
        if (amount == 0) revert ZeroAmount();

        // Cache storage variables.
        bytes32 merkleRoot_ = merkleRoot;
        uint256 redeemed_ = redeemed[merkleRoot_][msg.sender];

        // Verify proof.
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, maxRedeemable));
        bool isValidProof = MerkleProofLib.verifyCalldata(merkleProofs, merkleRoot_, leaf);
        if (!isValidProof) revert InvalidProof();

        // Calculate redeemable amount.
        if (redeemed_ >= maxRedeemable) revert AlreadyRedeemed();
        uint256 redeemable = maxRedeemable - redeemed_;
        if (redeemable < amount) amount = redeemable;

        // Update redeemed amount.
        redeemed[merkleRoot_][msg.sender] = redeemed_ + amount;

        // Transfer Recovery Tokens from caller and burn them.
        ERC20(RECOVERY_TOKEN).safeTransferFrom(msg.sender, address(this), amount);
        IRecoveryToken(RECOVERY_TOKEN).burn(amount);

        // Send redeemed fees from the treasury to caller.
        UNDERLYING_TOKEN.safeTransferFrom(treasury, msg.sender, amount);

        emit Redeemed(merkleRoot_, msg.sender, amount);
    }

    /**
     * @notice Checks the amount of Underlying Tokens a user can redeem.
     * @param user The address of the user to check.
     * @param maxRedeemable The maximum amount of tokens the user can redeem for the latest Merkle root.
     * @param merkleProofs Array of hashes providing proof of inclusion in the Merkle tree.
     * @return isValidProof Bool indicating if the proof is valid.
     * @return redeemable The amount of Underlying Tokens the user can redeem.
     */
    function getRedeemableAmount(address user, uint256 maxRedeemable, bytes32[] calldata merkleProofs)
        public
        view
        returns (bool isValidProof, uint256 redeemable)
    {
        // Cache storage variables.
        bytes32 merkleRoot_ = merkleRoot;
        uint256 redeemed_ = redeemed[merkleRoot_][user];

        // Verify proof.
        bytes32 leaf = keccak256(abi.encodePacked(user, maxRedeemable));
        isValidProof = MerkleProofLib.verifyCalldata(merkleProofs, merkleRoot_, leaf);
        if (!isValidProof) return (false, 0);

        // Calculate redeemable amount.
        if (redeemed_ >= maxRedeemable) return (true, 0);
        redeemable = maxRedeemable - redeemed_;
    }
}
