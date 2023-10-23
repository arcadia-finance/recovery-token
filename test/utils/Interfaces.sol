// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IUSDC {
    function blacklister() external view returns (address blacklister);

    function blacklist(address _account) external;
}
