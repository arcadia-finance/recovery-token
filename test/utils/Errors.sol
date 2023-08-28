/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

/// @notice Abstract contract containing all the errors emitted by the protocol.
abstract contract Errors {
    /*//////////////////////////////////////////////////////////////
                            RECOVERY TOKEN
    //////////////////////////////////////////////////////////////*/

    error NotRecoveryController();

    /*//////////////////////////////////////////////////////////////
                        RECOVERY CONTROLLER
    //////////////////////////////////////////////////////////////*/

    error NotActive();

    error Active();

    error NoTransfersAllowed();

    error LengthMismatch();

    error DepositAmountZero();

    error WithdrawAmountZero();
}
