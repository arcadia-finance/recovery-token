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
 * @title Fee Claimer.
 * @author Pragma Labs
 * @notice Uses a Merkle tree to efficiently verify claims of fees.
 */
contract FeeClaimer is Owned {
    using SafeTransferLib for ERC20;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Recovery Token.
    address public immutable RECOVERY_TOKEN;

    // The contract address of the Underlying Token in which the fees are denominated.
    ERC20 public immutable UNDERLYING_TOKEN;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    // The root of the Merkle tree containing valid claims.
    bytes32 public merkleRoot;

    // The contract address of the treasury, holding the claimable underlying tokens.
    address public treasury;

    // A mapping to track per merkle root which users has claimed how much fees.
    mapping(bytes32 root => mapping(address user => uint256 amount)) public claimed;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event Claimed(bytes32 indexed root, address indexed user, uint256 amount);
    event MerkleRootSet(bytes32 indexed merkleRoot);
    event TreasurySet(address indexed treasury);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error AlreadyClaimed();
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
     * @notice Claims Underlying Tokens for eligible users verified by Merkle proof.
     * @param amount The amount of tokens the user wants to claim.
     * @param maxClaimable The maximum amount of tokens the user can claim for the latest Merkle root.
     * @param merkleProofs Array of hashes providing proof of inclusion in the Merkle tree.
     * @dev Treasury has to approve this contract to spend the total claimable amount of Underlying Tokens.
     * @dev Caller has to approve this contract to spend the claimable amount of Recovery Tokens.
     */
    function claim(uint256 amount, uint256 maxClaimable, bytes32[] calldata merkleProofs) external {
        if (amount == 0) revert ZeroAmount();

        // Cache storage variables.
        bytes32 merkleRoot_ = merkleRoot;
        uint256 claimed_ = claimed[merkleRoot_][msg.sender];

        // Verify proof.
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, maxClaimable));
        bool isValidProof = MerkleProofLib.verifyCalldata(merkleProofs, merkleRoot_, leaf);
        if (!isValidProof) revert InvalidProof();

        // Calculate claimable amount.
        if (claimed_ >= maxClaimable) revert AlreadyClaimed();
        uint256 claimable = maxClaimable - claimed_;
        if (claimable < amount) amount = claimable;

        // Update claimed amount.
        claimed[merkleRoot_][msg.sender] = claimed_ + amount;

        // Transfer Recovery Tokens from caller and burn them.
        ERC20(RECOVERY_TOKEN).safeTransferFrom(msg.sender, address(this), amount);
        IRecoveryToken(RECOVERY_TOKEN).burn(amount);

        // Send claimed fees from the treasury to caller.
        UNDERLYING_TOKEN.safeTransferFrom(treasury, msg.sender, amount);

        emit Claimed(merkleRoot_, msg.sender, amount);
    }

    /**
     * @notice Checks the amount of Underlying Tokens a user can claim.
     * @param user The address of the user to check.
     * @param maxClaimable The maximum amount of tokens the user can claim for the latest Merkle root.
     * @param merkleProofs Array of hashes providing proof of inclusion in the Merkle tree.
     * @return isValidProof Bool indicating if the proof is valid.
     * @return claimable The amount of Underlying Tokens the user can claim.
     */
    function getClaimableAmount(address user, uint256 maxClaimable, bytes32[] calldata merkleProofs)
        public
        view
        returns (bool isValidProof, uint256 claimable)
    {
        // Cache storage variables.
        bytes32 merkleRoot_ = merkleRoot;
        uint256 claimed_ = claimed[merkleRoot_][user];

        // Verify proof.
        bytes32 leaf = keccak256(abi.encodePacked(user, maxClaimable));
        isValidProof = MerkleProofLib.verifyCalldata(merkleProofs, merkleRoot_, leaf);
        if (!isValidProof) return (false, 0);

        // Calculate claimable amount.
        if (claimed_ >= maxClaimable) return (true, 0);
        claimable = maxClaimable - claimed_;
    }
}
