/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

struct Users {
    address payable creator;
    address payable owner;
    address payable tokenCreator;
    address payable aggrievedUser0;
    address payable aggrievedUser1;
    address payable alice;
    address payable bob;
}

struct UserState {
    address addr;
    uint256 redeemed;
    uint256 redeemablePerRTokenLast;
    uint256 balanceWRT;
    uint256 balanceRT;
    uint256 balanceUT;
}

struct ControllerState {
    bool active;
    uint256 redeemablePerRTokenGlobal;
    uint256 supplyWRT;
    uint256 balanceRT;
    uint256 balanceUT;
}
