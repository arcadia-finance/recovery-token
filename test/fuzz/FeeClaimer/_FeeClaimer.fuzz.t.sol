/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Fuzz_Test } from "../Fuzz.t.sol";
import { FeeClaimerExtension } from "../../utils/extensions/FeeClaimerExtension.sol";

/**
 * @notice Common logic needed by all "FeeClaimer" fuzz tests.
 */
abstract contract FeeClaimer_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct GlobalState {
        uint64 balanceUT;
        bytes32 root;
    }

    struct UserState {
        address user;
        uint64 maxClaimable;
        uint64 claimed;
        uint64 amount;
        uint64 balanceRT;
        bytes32 proof;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    FeeClaimerExtension internal feeClaimer;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Fuzz_Test.setUp();

        // Deploy Recovery contracts.
        deployRecoveryContracts();

        // Deploy FeeClaimer.
        vm.prank(users.creator);
        feeClaimer = new FeeClaimerExtension(users.owner, address(recoveryController), users.treasury);
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function getMerkleRoot(UserState memory userState) internal pure returns (bytes32 root) {
        bytes32 leaf = keccak256(abi.encodePacked(userState.user, uint256(userState.maxClaimable)));
        root = commutativeKeccak256(leaf, userState.proof);
    }

    function commutativeKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a);
    }

    function efficientKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32 value) {
        assembly ("memory-safe") {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function givenValidState(GlobalState memory globalState, UserState memory userState) internal view {
        vm.assume(userState.user != users.treasury);
        vm.assume(userState.user != address(feeClaimer));

        userState.amount = uint64(bound(userState.amount, 1, type(uint64).max));
        userState.maxClaimable = uint64(bound(userState.maxClaimable, 1, type(uint64).max));
        userState.claimed = uint64(bound(userState.claimed, 0, userState.maxClaimable - 1));
        uint256 claimable = userState.maxClaimable - userState.claimed;
        userState.balanceRT = uint64(
            bound(userState.balanceRT, claimable < userState.amount ? claimable : userState.amount, type(uint64).max)
        );

        globalState.balanceUT = uint64(bound(globalState.balanceUT, claimable, type(uint64).max));
        globalState.root = getMerkleRoot(userState);
    }

    function setState(GlobalState memory globalState, UserState memory userState) internal {
        vm.prank(users.owner);
        feeClaimer.setMerkleRoot(globalState.root);
        deal(address(underlyingToken), users.treasury, globalState.balanceUT);

        feeClaimer.setClaimed(globalState.root, userState.user, userState.claimed);
        deal(address(recoveryToken), userState.user, userState.balanceRT);
    }
}
