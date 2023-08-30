/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/// @notice Abstract contract containing all the events emitted by the protocol.
abstract contract Events {
    /*//////////////////////////////////////////////////////////////
                        RECOVERY CONTROLLER
    //////////////////////////////////////////////////////////////*/

    event ActivationSet(bool active);

    event TerminationInitiated(uint32 timestamp);
}
