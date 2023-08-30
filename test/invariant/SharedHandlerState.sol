/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";

contract SharedHandlerState is StdUtils {
    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    address[] public actors;

    /*//////////////////////////////////////////////////////////////
                               SETUP
    //////////////////////////////////////////////////////////////*/

    function addActor(address actor) external {
        actors.push(actor);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    function getActor(uint256 actorIndexSeed) external view returns (address actor) {
        actor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
    }

    function getActorsLength() public view returns (uint256 actorsLength) {
        actorsLength = actors.length;
    }
}
