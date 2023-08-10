// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";

import {IRecoveryToken} from "./interfaces/IRecoveryToken.sol";

contract IRecoveryController is ERC20, Owned {
    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    bool public active;

    uint256 public cumulativeRecoveryPerShare;

    address internal underlying;
    address internal recoveryToken;

    mapping(address => uint256) internal cumulativeRecoveryPerShareLast;
    mapping(address => uint256) public redeemed;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAllowed();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier isActive() {
        require(active, "NOT ACTIVE");

        _;
    }

    modifier notActive() {
        require(!active, "NOT ACTIVE");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("Arcadia Recovery Shares", "ARS", 18) Owned(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                        RECOVERY TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function depositRecoveryToken(uint256 amount) external isActive {}

    function withdrawRecoveryToken(uint256 amount) external isActive {}

    function redeemUnderlying() external isActive {
        _redeemUnderlying();
    }

    function _redeemUnderlying() internal {
        uint256 redeemable =
            balanceOf[msg.sender] * (cumulativeRecoveryPerShare - cumulativeRecoveryPerShareLast[msg.sender]);
        cumulativeRecoveryPerShareLast[msg.sender] = cumulativeRecoveryPerShare;

        if (balanceOf[msg.sender] >= redeemable + redeemed[msg.sender]) {
            redeemed[msg.sender] += redeemable;
        } else {
            uint256 surplus = redeemable + redeemed[msg.sender] - balanceOf[msg.sender];

            redeemable = balanceOf[msg.sender] - redeemed[msg.sender];
            _burn(msg.sender, balanceOf[msg.sender]);
            // Distribute surplus to other shareHolders.
            _distributeUnderlying(surplus);
        }

        IRecoveryToken(recoveryToken).burn(redeemable);
        ERC20(underlying).transfer(msg.sender, redeemable);
    }

    function depositUnderlying(uint256 amount) external {
        _distributeUnderlying(amount);
        ERC20(underlying).transferFrom(msg.sender, address(this), amount);
    }

    function _distributeUnderlying(uint256 amount) internal {
        // ToDo: Do Check that total deposited amount does not exceed total shares
        cumulativeRecoveryPerShare += 1e18 * amount / totalSupply;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/
    function transfer(address, uint256) public pure override returns (bool) {
        revert NotAllowed();
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert NotAllowed();
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/
    function mint(address to, uint256 amount) external onlyOwner notActive {
        _mint(to, amount);
        IRecoveryToken(recoveryToken).mint(amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
        IRecoveryToken(recoveryToken).burn(amount);
    }
}
