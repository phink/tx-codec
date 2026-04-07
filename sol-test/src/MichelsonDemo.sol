// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Michelson.sol";
import "./MichelsonSpec.sol";

/// @notice Demo contract for Michelson PACK codec on Etherlink.
///         Exercises encode/decode for all atom types via assembly-optimized library.
contract MichelsonDemo {

    // ================================================================
    // NAT: encode + decode roundtrip
    // ================================================================

    function packNat(uint256 n) external pure returns (bytes memory) {
        return Michelson.packNat(n);
    }

    function unpackNat(bytes calldata packed) external pure returns (uint256) {
        return Michelson.unpackNat(packed);
    }

    function roundtripNat(uint256 n) external pure returns (uint256) {
        bytes memory packed = Michelson.packNat(n);
        return Michelson.unpackNat(packed);
    }

    // ================================================================
    // INT: encode + decode roundtrip
    // ================================================================

    function packInt(int256 v) external pure returns (bytes memory) {
        return Michelson.packInt(v);
    }

    function unpackInt(bytes calldata packed) external pure returns (int256) {
        return Michelson.unpackInt(packed);
    }

    function roundtripInt(int256 v) external pure returns (int256) {
        bytes memory packed = Michelson.packInt(v);
        return Michelson.unpackInt(packed);
    }

    // ================================================================
    // BOOL: encode + decode roundtrip
    // ================================================================

    function packBool(bool b) external pure returns (bytes memory) {
        return Michelson.packBool(b);
    }

    function unpackBool(bytes calldata packed) external pure returns (bool) {
        return Michelson.unpackBool(packed);
    }

    // ================================================================
    // STRING: encode + decode roundtrip
    // ================================================================

    function packString(string calldata s) external pure returns (bytes memory) {
        return Michelson.packString(s);
    }

    function unpackString(bytes calldata packed) external pure returns (string memory) {
        return Michelson.unpackString(packed);
    }

    // ================================================================
    // COMPOSITE: pair(nat, int)
    // ================================================================

    function packPair(uint256 n, int256 v) external pure returns (bytes memory) {
        return MichelsonSpec.pack(
            MichelsonSpec.pair(MichelsonSpec.nat(n), MichelsonSpec.int_(v))
        );
    }

    // ================================================================
    // Full demo: encode multiple types, verify roundtrips
    // ================================================================

    function demo() external pure returns (
        bool natOk,
        bool intOk,
        bool boolOk,
        bool stringOk,
        bytes memory natPacked,
        bytes memory intPacked,
        bytes memory pairPacked
    ) {
        // NAT roundtrip
        natPacked = Michelson.packNat(42);
        natOk = (Michelson.unpackNat(natPacked) == 42);

        // INT roundtrip
        intPacked = Michelson.packInt(-42);
        intOk = (Michelson.unpackInt(intPacked) == -42);

        // BOOL roundtrip
        bytes memory boolPacked = Michelson.packBool(true);
        boolOk = (Michelson.unpackBool(boolPacked) == true);

        // STRING roundtrip
        bytes memory strPacked = Michelson.packString("hello");
        stringOk = (keccak256(bytes(Michelson.unpackString(strPacked))) == keccak256("hello"));

        // PAIR encode
        pairPacked = MichelsonSpec.pack(
            MichelsonSpec.pair(MichelsonSpec.nat(42), MichelsonSpec.int_(-42))
        );
    }
}
