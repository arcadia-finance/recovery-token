/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { UserState } from "./Types.sol";

abstract contract Utils {
    mapping(address => bool) seen;

    /**
     * @notice Casts a static array of addresses of length two to a dynamic array of addresses.
     * @param staticArray The static array of addresses.
     * @return dynamicArray The dynamic array of addresses.
     */
    function castArrayStaticToDynamic(address[2] calldata staticArray)
        public
        pure
        returns (address[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new address[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Casts a static array of uints of length two to a dynamic array of uints.
     * @param staticArray The static array of uints.
     * @return dynamicArray The dynamic array of uints.
     */
    function castArrayStaticToDynamic(uint256[2] calldata staticArray)
        public
        pure
        returns (uint256[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new uint256[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Casts a static array of UserStates of length two to a dynamic array of UserStates.
     * @param staticArray The static array of UserStates.
     * @return dynamicArray The dynamic array of UserStates.
     */
    function castArrayStaticToDynamicUserState(UserState[2] calldata staticArray)
        public
        pure
        returns (UserState[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new UserState[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Checks if all addresses of an array are unique.
     * @param addressesArray The array of addresses.
     * @return bool indicating of all addresses are unique.
     */
    function uniqueAddresses(address[] memory addressesArray) public returns (bool) {
        uint256 length = addressesArray.length;
        for (uint256 i; i < length;) {
            if (seen[addressesArray[i]]) {
                return false;
            } else {
                seen[addressesArray[i]] = true;
            }

            unchecked {
                ++i;
            }
        }
        return true;
    }

    /**
     * @notice Checks if all user-addresses in an array of UserStates are unique.
     * @param userArray The array of UserStates.
     * @return bool indicating of all addresses are unique.
     */
    function uniqueUsers(UserState[] memory userArray) public returns (bool) {
        uint256 length = userArray.length;
        address userAddr;
        for (uint256 i; i < length;) {
            userAddr = userArray[i].addr;
            if (seen[userAddr]) {
                return false;
            } else {
                seen[userAddr] = true;
            }

            unchecked {
                ++i;
            }
        }
        return true;
    }
}
