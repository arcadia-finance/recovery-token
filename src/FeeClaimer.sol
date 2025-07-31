/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";
import { IRecoveryToken } from "./interfaces/IRecoveryToken.sol";
import { MerkleProofLib } from "../lib/solady/src/utils/MerkleProofLib.sol";
import { Owned } from "../lib/solmate/src/auth/Owned.sol";
import { SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title .
 * @author Pragma Labs
 * @notice .
 */
contract FeeClaimer is Owned {
    using SafeTransferLib for ERC20;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Recovery Token.
    IRecoveryToken public immutable RECOVERY_TOKEN;
    // The contract address of USDC.
    ERC20 public immutable USDC;
    // The contract address of the treasury, holding the USDC.
    address internal immutable TREASURY;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    // The root of the Merkle tree containing valid claims.
    bytes32 public merkleRoot;
    // A mapping to track per merkle root which addresses has claimed fees.
    mapping(bytes32 root => mapping(address account => uint256 claimed)) public claimed;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event Claimed(bytes32 indexed root, address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error AlreadyClaimed();
    error InvalidAmount();
    error InvalidProof();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner_ The address of the Owner.
     * @param recoveryToken The contract address of the Recovery Token.
     * @param usdc The contract address of USDC.
     * @param treasury The address of the Arcadia treasury.
     * @param merkleRoot_ The root of the Merkle tree containing valid claims.
     */
    constructor(address owner_, address recoveryToken, address usdc, address treasury, bytes32 merkleRoot_)
        Owned(owner_)
    {
        RECOVERY_TOKEN = IRecoveryToken(recoveryToken);
        USDC = ERC20(usdc);
        TREASURY = treasury;
        merkleRoot = merkleRoot_;
    }

    /* //////////////////////////////////////////////////////////////
                            CLAIM LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Claims and stakes AAA tokens for eligible users verified by Merkle proof.
     * @param amount The amount of tokens the user wants to claim.
     * @param maxAmount The maximum amount of tokens the user can claim.
     * @param merkleProofs Array of hashes providing proof of inclusion in the Merkle tree.
     */
    function claim(uint256 amount, uint256 maxAmount, bytes32[] calldata merkleProofs) external {
        // Cache storage variables.
        bytes32 merkleRoot_ = merkleRoot;
        uint256 claimed_ = claimed[merkleRoot_][msg.sender];

        if (claimed_ >= maxAmount) revert AlreadyClaimed();
        if (maxAmount - claimed_ > amount) revert InvalidAmount();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, maxAmount));
        bool isValidProof = MerkleProofLib.verifyCalldata(merkleProofs, merkleRoot, leaf);
        if (!isValidProof) revert InvalidProof();

        claimed[merkleRoot_][msg.sender] = claimed_ + amount;

        // Transfer Recovery Tokens from caller and burn them.
        ERC20(address(RECOVERY_TOKEN)).safeTransferFrom(msg.sender, address(this), amount);
        RECOVERY_TOKEN.burn(amount);

        // Send fees to caller.
        USDC.safeTransferFrom(TREASURY, msg.sender, amount);

        emit Claimed(merkleRoot_, msg.sender, amount);
    }

    /**
     * @notice Checks if a user can claim tokens.
     * @param user The address of the user to check.
     * @param amount The amount of tokens to verify for the claim.
     * @param merkleProofs Array of hashes providing proof of inclusion in the Merkle tree.
     * @return isValidProof True if the user can claim tokens, false otherwise.
     */
    // function canClaim(address user, uint256 amount, bytes32[] calldata merkleProofs)
    //     public
    //     view
    //     returns (bool isValidProof)
    // {
    //     if (hasClaimed[user]) return false;
    //     bytes32 leaf = keccak256(abi.encodePacked(user, amount));
    //     isValidProof = MerkleProofLib.verifyCalldata(merkleProofs, merkleRoot, leaf);
    // }

    /**
     * @notice Sets a new root of the Merkle tree containing valid claims.
     * @param merkleRoot_ The new root of the Merkle tree.
     */
    function setMerkleRoot(bytes32 merkleRoot_) external onlyOwner {
        merkleRoot = merkleRoot_;
    }
}
