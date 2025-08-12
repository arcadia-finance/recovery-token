/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.30;

import { Fuzz_Test } from "../Fuzz.t.sol";
import { RedeemerExtension } from "../../utils/extensions/RedeemerExtension.sol";

/**
 * @notice Common logic needed by all "Redeemer" fuzz tests.
 */
abstract contract Redeemer_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct GlobalState {
        uint64 balanceUT;
        bytes32 root;
    }

    struct UserState {
        address user;
        uint64 maxRedeemable;
        uint64 redeemed;
        uint64 amount;
        uint64 balanceRT;
        bytes32 proof;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    RedeemerExtension internal redeemer;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Fuzz_Test.setUp();

        // Deploy Recovery contracts.
        deployRecoveryContracts();

        // Deploy Redeemer.
        vm.prank(users.creator);
        redeemer = new RedeemerExtension(users.owner, address(recoveryController), users.treasury);
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function getMerkleRoot(UserState memory userState) internal pure returns (bytes32 root) {
        bytes32 leaf = keccak256(abi.encodePacked(userState.user, uint256(userState.maxRedeemable)));
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
        vm.assume(userState.user != address(redeemer));

        userState.amount = uint64(bound(userState.amount, 1, type(uint64).max));
        userState.maxRedeemable = uint64(bound(userState.maxRedeemable, 1, type(uint64).max));
        userState.redeemed = uint64(bound(userState.redeemed, 0, userState.maxRedeemable - 1));
        uint256 redeemable = userState.maxRedeemable - userState.redeemed;
        userState.balanceRT = uint64(
            bound(userState.balanceRT, redeemable < userState.amount ? redeemable : userState.amount, type(uint64).max)
        );

        globalState.balanceUT = uint64(bound(globalState.balanceUT, redeemable, type(uint64).max));
        globalState.root = getMerkleRoot(userState);
    }

    function setState(GlobalState memory globalState, UserState memory userState) internal {
        vm.prank(users.owner);
        redeemer.setMerkleRoot(globalState.root);
        deal(address(underlyingToken), users.treasury, globalState.balanceUT);

        redeemer.setRedeemed(globalState.root, userState.user, userState.redeemed);
        deal(address(recoveryToken), userState.user, userState.balanceRT);
    }
}
