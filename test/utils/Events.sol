/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

/**
 * @notice Abstract contract containing all the events emitted by the protocol.
 */
abstract contract Events {
    /*//////////////////////////////////////////////////////////////
                        RECOVERY CONTROLLER
    //////////////////////////////////////////////////////////////*/

    event ActivationSet(bool active);

    event TerminationInitiated();

    /*//////////////////////////////////////////////////////////////
                            ERC20
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);
}
