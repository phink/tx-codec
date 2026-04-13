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
        return Michelson.pack(Michelson.nat(n));
    }

    function unpackNat(bytes calldata packed) external pure returns (uint256) {
        return Michelson.toNat(Michelson.unpack(packed));
    }

    function roundtripNat(uint256 n) external pure returns (uint256) {
        bytes memory packed = Michelson.pack(Michelson.nat(n));
        return Michelson.toNat(Michelson.unpack(packed));
    }

    // ================================================================
    // INT: encode + decode roundtrip
    // ================================================================

    function packInt(int256 v) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.int_(v));
    }

    function unpackInt(bytes calldata packed) external pure returns (int256) {
        return Michelson.toInt(Michelson.unpack(packed));
    }

    function roundtripInt(int256 v) external pure returns (int256) {
        bytes memory packed = Michelson.pack(Michelson.int_(v));
        return Michelson.toInt(Michelson.unpack(packed));
    }

    // ================================================================
    // BOOL: encode + decode roundtrip
    // ================================================================

    function packBool(bool b) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.bool_(b));
    }

    function unpackBool(bytes calldata packed) external pure returns (bool) {
        return Michelson.toBool(Michelson.unpack(packed));
    }

    // ================================================================
    // STRING: encode + decode roundtrip
    // ================================================================

    function packString(string calldata s) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.string_(s));
    }

    function unpackString(bytes calldata packed) external pure returns (string memory) {
        return Michelson.toString(Michelson.unpack(packed));
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
        natPacked = Michelson.pack(Michelson.nat(42));
        natOk = (Michelson.toNat(Michelson.unpack(natPacked)) == 42);

        // INT roundtrip
        intPacked = Michelson.pack(Michelson.int_(-42));
        intOk = (Michelson.toInt(Michelson.unpack(intPacked)) == -42);

        // BOOL roundtrip
        bytes memory boolPacked = Michelson.pack(Michelson.bool_(true));
        boolOk = (Michelson.toBool(Michelson.unpack(boolPacked)) == true);

        // STRING roundtrip
        bytes memory strPacked = Michelson.pack(Michelson.string_("hello"));
        stringOk = (keccak256(bytes(Michelson.toString(Michelson.unpack(strPacked)))) == keccak256("hello"));

        // PAIR encode
        pairPacked = MichelsonSpec.pack(
            MichelsonSpec.pair(MichelsonSpec.nat(42), MichelsonSpec.int_(-42))
        );
    }
}
