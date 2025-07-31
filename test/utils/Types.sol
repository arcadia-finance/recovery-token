/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

struct Users {
    address payable tokenCreator;
    address payable creator;
    address payable owner;
    address payable holderSRT0;
    address payable holderSRT1;
    address payable alice;
    address payable bob;
    address payable treasury;
}

struct UserState {
    address addr;
    uint256 redeemed;
    uint256 redeemablePerRTokenLast;
    uint256 balanceSRT;
    uint256 balanceRT;
    uint256 balanceUT;
}

struct ControllerState {
    bool active;
    uint256 redeemablePerRTokenGlobal;
    uint256 supplySRT;
    uint256 balanceRT;
    uint256 balanceUT;
}
