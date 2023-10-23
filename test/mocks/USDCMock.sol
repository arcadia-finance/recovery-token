/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";

contract USDCMock is ERC20 {
    mapping(address => bool) internal blacklisted;

    constructor(string memory name_, string memory symbol_, uint8 decimalsInput_)
        ERC20(name_, symbol_, decimalsInput_)
    {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function blacklist(address _account) external {
        blacklisted[_account] = true;
    }

    function unBlacklist(address _account) external {
        blacklisted[_account] = false;
    }

    function isBlacklisted(address _account) external view returns (bool) {
        return blacklisted[_account];
    }
}
