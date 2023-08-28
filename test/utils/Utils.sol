/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

abstract contract Utils {
    mapping(address => bool) seen;

    function castArrayFixedToDynamic(address[2] calldata fixedSizedArray)
        public
        pure
        returns (address[] memory dynamicSizedArray)
    {
        uint256 length = fixedSizedArray.length;
        dynamicSizedArray = new address[](length);

        for (uint256 i; i < length;) {
            dynamicSizedArray[i] = fixedSizedArray[i];

            unchecked {
                ++i;
            }
        }
    }

    function castArrayFixedToDynamic(uint256[2] calldata fixedSizedArray)
        public
        pure
        returns (uint256[] memory dynamicSizedArray)
    {
        uint256 length = fixedSizedArray.length;
        dynamicSizedArray = new uint256[](length);

        for (uint256 i; i < length;) {
            dynamicSizedArray[i] = fixedSizedArray[i];

            unchecked {
                ++i;
            }
        }
    }

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
}
