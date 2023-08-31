/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

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

    error DepositAmountZero();

    error WithdrawAmountZero();

    error TerminationCoolDownPeriodNotPassed();
}
