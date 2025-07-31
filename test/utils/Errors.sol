/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

/**
 * @notice Abstract contract containing all the errors emitted by the protocol.
 */
abstract contract Errors {
    /*//////////////////////////////////////////////////////////////
                            RECOVERY TOKEN
    //////////////////////////////////////////////////////////////*/

    error NotRecoveryController();

    /*//////////////////////////////////////////////////////////////
                        RECOVERY CONTROLLER
    //////////////////////////////////////////////////////////////*/

    error ControllerTerminated();

    error NotActive();

    error Active();

    error NoTransfersAllowed();

    error LengthMismatch();

    error ZeroAmount();

    error TerminationCoolDownPeriodNotPassed();
}
