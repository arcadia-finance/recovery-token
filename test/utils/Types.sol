/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import {ERC20Mock} from "../mocks/ERC20Mock.sol";

struct Users {
    address payable creator;
    address payable owner;
    address payable tokenCreator;
    address payable aggrievedUser0;
    address payable aggrievedUser1;
}
