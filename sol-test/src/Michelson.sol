// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MichelsonSpec.sol";

/// @notice Assembly-optimized Michelson PACK encoders/decoders.
/// @dev Must produce identical results to MichelsonSpec (the IR-generated spec).
///      Differential fuzz tests enforce equivalence (96 asm-diff + 330 total).
///      Each public function is a single monolithic assembly block with comments
///      marking correspondence to the IR-generated MichelsonSpec functions.
///      MichelsonSpec is fully generated from the SolStmt IR transpiler (all 52 functions).
library Michelson {

    // ================================================================
    // Public decoders (monolithic inline assembly)
    // ================================================================

    /// @notice Decode Michelson PACK bytes to uint256 using assembly.
    function unpackNat(bytes memory packed) internal pure returns (uint256 value) {
        assembly {
            let len := mload(packed)
            let ptr := add(packed, 32)

            // -- Corresponds to MichelsonSpec.unpack (version byte 0x05 check)
            //    + MichelsonSpec.toNat (node tag 0x00 check, length >= 2)
            //    IR structure: unpack checks packed.length < 1 and packed[0] != 0x05;
            //    toNat checks micheline.length < 2 and micheline[0] != 0x00.
            //    Combined here: packed needs >= 3 bytes (0x05 + 0x00 + >=1 zarith byte).
            if lt(len, 3) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }
            let hdr := mload(ptr)
            let b0 := byte(0, hdr)
            if iszero(eq(b0, 0x05)) {
                mstore(0, shl(224, 0xe51a2409)) // InvalidVersionByte(uint8)
                mstore(4, b0)
                revert(0, 36)
            }
            let b1 := byte(1, hdr)
            if iszero(eq(b1, 0x00)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x00)
                mstore(36, b1)
                revert(0, 68)
            }

            // -- Corresponds to MichelsonSpec._decodeZarithNat(micheline, 1) --
            // IR structure (nested if/else):
            //   if offset < data.length -> read first = uint8(data[offset])
            //     if first >= 128:
            //       if first >= 192: revert NatNegative()
            //       else: (first % 64 + tailValue, tailNewOff) via _decodeZarithTail
            //     else (first < 128):
            //       if first >= 64: revert NatNegative()
            //       else: return (first, offset + 1)
            //   else: revert InputTruncated()
            // Assembly flattens this into switch/if chains on first's range.
            let offset := 2
            let remaining := sub(len, offset)
            if lt(remaining, 1) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated
                revert(0, 4)
            }

            let first := byte(0, mload(add(ptr, offset)))
            let newOffset := 0

            switch lt(first, 64)
            case 1 {
                // first < 64: single byte positive — spec returns (first, offset + 1)
                value := first
                newOffset := add(offset, 1)
            }
            default {
                // first >= 64
                switch lt(first, 128)
                case 1 {
                    // 64 <= first < 128: spec's inner "if first >= 64: revert NatNegative()"
                    mstore(0, shl(224, 0x6a525171)) // NatNegative
                    revert(0, 4)
                }
                default {
                    // first >= 128: multi-byte path
                    if gt(first, 191) {
                        // first >= 192: spec's "if first >= 192: revert NatNegative()"
                        mstore(0, shl(224, 0x6a525171)) // NatNegative
                        revert(0, 4)
                    }

                    // -- Corresponds to MichelsonSpec._decodeZarithTail(data, offset+1, 6) --
                    // IR structure (recursive, unrolled here as a loop):
                    //   if b >= 128: accumulate (b % 128) << shift, recurse with shift+7
                    //   else if b == 0: revert TrailingZeroByte()
                    //   else: terminal byte, return (b << shift, offset+1)
                    let tailOffset := add(offset, 1)
                    let shift := 6

                    if iszero(lt(tailOffset, len)) {
                        mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated
                        revert(0, 4)
                    }

                    let tailValue := 0
                    let tailRemaining := sub(len, tailOffset)
                    let tailPtr := add(ptr, tailOffset)
                    let done := 0

                    for { let i := 0 } lt(i, tailRemaining) { i := add(i, 1) } {
                        let byt := byte(0, mload(add(tailPtr, i)))

                        switch gt(byt, 127)
                        case 1 {
                            // Continuation byte
                            tailValue := or(tailValue, shl(shift, and(byt, 0x7f)))
                            shift := add(shift, 7)
                            if gt(shift, 255) {
                                mstore(0, shl(224, 0x44dddea2)) // IntOverflow
                                revert(0, 4)
                            }
                        }
                        case 0 {
                            // Terminal byte
                            if iszero(byt) {
                                mstore(0, shl(224, 0x96d10b2a)) // TrailingZeroByte
                                revert(0, 4)
                            }
                            tailValue := or(tailValue, shl(shift, byt))
                            newOffset := add(tailOffset, add(i, 1))
                            done := 1
                            i := tailRemaining // break
                        }
                    }

                    if iszero(done) {
                        mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated
                        revert(0, 4)
                    }

                    // spec: return ((first % 64) + tv, newOff)
                    // first & 0x3f == first % 64
                    value := add(and(first, 0x3f), tailValue)
                }
            }

            // -- Corresponds to MichelsonSpec.toNat: trailing bytes check --
            // IR: if (consumed != micheline.length) revert TrailingBytes(consumed, micheline.length)
            if iszero(eq(newOffset, len)) {
                mstore(0, shl(224, 0xc3e44a73)) // TrailingBytes(uint256,uint256)
                mstore(4, newOffset)
                mstore(36, len)
                revert(0, 68)
            }
        }
    }

    /// @notice Decode Michelson PACK bytes to int256 using assembly.
    function unpackInt(bytes memory packed) internal pure returns (int256 value) {
        assembly {
            let len := mload(packed)
            let ptr := add(packed, 32)

            // -- Corresponds to MichelsonSpec.unpack (version byte 0x05 check)
            //    + MichelsonSpec.toInt (node tag 0x00 check, length >= 2)
            //    IR structure: same header validation as toNat (see above).
            if lt(len, 3) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }
            let hdr := mload(ptr)
            let b0 := byte(0, hdr)
            if iszero(eq(b0, 0x05)) {
                mstore(0, shl(224, 0xe51a2409)) // InvalidVersionByte(uint8)
                mstore(4, b0)
                revert(0, 36)
            }
            let b1 := byte(1, hdr)
            if iszero(eq(b1, 0x00)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x00)
                mstore(36, b1)
                revert(0, 68)
            }

            // -- Corresponds to MichelsonSpec._decodeZarithInt(micheline, 1) --
            // IR structure (nested if/else):
            //   if first < 64: return (int256(first), offset+1)                    [positive single]
            //   else if first < 128:
            //     if first == 64: revert NegativeZero()
            //     else: return (-(int256(first - 64)), offset+1)                   [negative single]
            //   else if first < 192:
            //     (tv, newOff) = _decodeZarithTail(..., 6)
            //     return (int256(first%64 + tv), newOff)                            [positive multi]
            //   else:
            //     (tv, newOff) = _decodeZarithTail(..., 6)
            //     return (-(int256(first%64 + tv)), newOff)                         [negative multi]
            // Assembly flattens into switch/if chains.
            let offset := 2
            let remaining := sub(len, offset)
            if lt(remaining, 1) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated
                revert(0, 4)
            }

            let first := byte(0, mload(add(ptr, offset)))
            let newOffset := 0

            switch lt(first, 64)
            case 1 {
                // first < 64: positive single-byte — spec: int256(first)
                value := first
                newOffset := add(offset, 1)
            }
            default {
                switch lt(first, 128)
                case 1 {
                    // 64 <= first < 128: negative single-byte
                    // spec: if first == 64 revert NegativeZero(); else -(int256(first - 64))
                    if eq(first, 64) {
                        mstore(0, shl(224, 0x7c1f7fe8)) // NegativeZero
                        revert(0, 4)
                    }
                    value := sub(0, sub(first, 64))
                    newOffset := add(offset, 1)
                }
                default {
                    // first >= 128: multi-byte
                    // spec: first < 192 -> positive, first >= 192 -> negative
                    let negative := gt(first, 191)
                    let low6 := and(first, 0x3f)

                    // -- Corresponds to MichelsonSpec._decodeZarithTail(data, offset+1, 6) --
                    // IR structure: same recursive tail decoder as in _decodeZarithNat path
                    let tailOffset := add(offset, 1)
                    let shift := 6

                    if iszero(lt(tailOffset, len)) {
                        mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated
                        revert(0, 4)
                    }

                    let tailValue := 0
                    let tailRemaining := sub(len, tailOffset)
                    let tailPtr := add(ptr, tailOffset)
                    let done := 0

                    for { let i := 0 } lt(i, tailRemaining) { i := add(i, 1) } {
                        let byt := byte(0, mload(add(tailPtr, i)))

                        switch gt(byt, 127)
                        case 1 {
                            // Continuation byte
                            tailValue := or(tailValue, shl(shift, and(byt, 0x7f)))
                            shift := add(shift, 7)
                            if gt(shift, 255) {
                                mstore(0, shl(224, 0x44dddea2)) // IntOverflow
                                revert(0, 4)
                            }
                        }
                        case 0 {
                            // Terminal byte
                            if iszero(byt) {
                                mstore(0, shl(224, 0x96d10b2a)) // TrailingZeroByte
                                revert(0, 4)
                            }
                            tailValue := or(tailValue, shl(shift, byt))
                            newOffset := add(tailOffset, add(i, 1))
                            done := 1
                            i := tailRemaining // break
                        }
                    }

                    if iszero(done) {
                        mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated
                        revert(0, 4)
                    }

                    // spec: (first % 64) + tv — same as (first & 0x3f) + tailValue
                    let absValue := add(low6, tailValue)

                    // -- Corresponds to MichelsonSpec._decodeZarithInt: sign handling --
                    // IR: first < 192 -> return int256(absValue)
                    //     first >= 192 -> return -(int256(absValue))
                    switch negative
                    case 1 {
                        if gt(absValue, shl(255, 1)) {
                            mstore(0, shl(224, 0x44dddea2)) // IntOverflow
                            revert(0, 4)
                        }
                        value := sub(0, absValue)
                    }
                    default {
                        if gt(absValue, sub(shl(255, 1), 1)) {
                            mstore(0, shl(224, 0x44dddea2)) // IntOverflow
                            revert(0, 4)
                        }
                        value := absValue
                    }
                }
            }

            // -- Corresponds to MichelsonSpec.toInt: trailing bytes check --
            // IR: if (consumed != micheline.length) revert TrailingBytes(consumed, micheline.length)
            if iszero(eq(newOffset, len)) {
                mstore(0, shl(224, 0xc3e44a73)) // TrailingBytes(uint256,uint256)
                mstore(4, newOffset)
                mstore(36, len)
                revert(0, 68)
            }
        }
    }

    // ================================================================
    // Optimized packToEVMNat / packToEVMInt / packToEVMBool
    // ================================================================

    function packToEVMNat(bytes memory packed) internal pure returns (bytes32) {
        return bytes32(unpackNat(packed));
    }

    function packToEVMInt(bytes memory packed) internal pure returns (bytes32) {
        return bytes32(uint256(unpackInt(packed)));
    }

    // ================================================================
    // Public encoders (monolithic inline assembly)
    // ================================================================

    /// @notice Encode uint256 as Michelson PACK bytes using assembly.
    function packNat(uint256 n) internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            let ptr := add(result, 32)

            // -- Corresponds to MichelsonSpec.pack(MichelsonSpec.nat(n)) --
            // IR: pack prepends 0x05; nat prepends 0x00 tag
            mstore8(ptr, 0x05)
            mstore8(add(ptr, 1), 0x00)
            let len := 2

            // -- Corresponds to MichelsonSpec._encodeZarithNat(n) --
            // IR: low6 = n % 64, rest = n / 64
            //   if rest >= 1: uint8(low6 + 128) ++ _encodeZarithTail(rest)
            //   else: uint8(low6)
            let low6 := mod(n, 64)
            let rest := div(n, 64)

            switch rest
            case 0 {
                // rest == 0: single byte — spec: uint8(low6)
                mstore8(add(ptr, len), low6)
                len := add(len, 1)
            }
            default {
                // rest >= 1: first byte = low6 + 128 — spec: uint8(low6 + 128)
                mstore8(add(ptr, len), add(low6, 128))
                len := add(len, 1)

                // -- Corresponds to MichelsonSpec._encodeZarithTail(rest) --
                // IR (recursive, unrolled as loop):
                //   if rest == 0: empty
                //   if rest < 128: uint8(rest) — terminal
                //   else: uint8(rest%128 + 128) ++ _encodeZarithTail(rest/128)
                for {} gt(rest, 127) {} {
                    mstore8(add(ptr, len), add(mod(rest, 128), 128))
                    rest := div(rest, 128)
                    len := add(len, 1)
                }
                // Terminal byte
                mstore8(add(ptr, len), rest)
                len := add(len, 1)
            }

            mstore(result, len)
            mstore(0x40, and(add(add(ptr, len), 31), not(31)))
        }
    }

    /// @notice Encode int256 as Michelson PACK bytes using assembly.
    function packInt(int256 v) internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            let ptr := add(result, 32)

            // -- Corresponds to MichelsonSpec.pack(MichelsonSpec.int_(v)) --
            // IR: pack prepends 0x05; int_ prepends 0x00 tag
            mstore8(ptr, 0x05)
            mstore8(add(ptr, 1), 0x00)
            let len := 2

            // -- Corresponds to MichelsonSpec._encodeZarithInt(v) --
            // IR structure:
            //   if z >= 0: _encodeZarithNat(uint256(z))
            //   else (unchecked): a = uint256(-z), signBit = 64
            //     if a < 64: uint8(a + 64)
            //     else: uint8(a%64 + 64 + 128) ++ _encodeZarithTail(a/64)
            // Assembly unifies positive/negative paths via signBit variable.
            let a := v
            let signBit := 0
            if slt(v, 0) {
                a := sub(0, v)
                signBit := 64
            }

            let low6 := mod(a, 64)
            let rest := div(a, 64)

            switch rest
            case 0 {
                // Single byte: spec's uint8(low6) or uint8(a + 64)
                mstore8(add(ptr, len), add(low6, signBit))
                len := add(len, 1)
            }
            default {
                // Multi-byte: spec's uint8(low6 + 128) or uint8(a%64 + 64 + 128)
                mstore8(add(ptr, len), add(add(low6, signBit), 128))
                len := add(len, 1)

                // -- Corresponds to MichelsonSpec._encodeZarithTail(rest) --
                // IR: same recursive tail encoder as in _encodeZarithNat path
                for {} gt(rest, 127) {} {
                    mstore8(add(ptr, len), add(mod(rest, 128), 128))
                    rest := div(rest, 128)
                    len := add(len, 1)
                }
                // Terminal byte
                mstore8(add(ptr, len), rest)
                len := add(len, 1)
            }

            mstore(result, len)
            mstore(0x40, and(add(add(ptr, len), 31), not(31)))
        }
    }

    // ================================================================
    // Optimized packToEVMBool: PACK bytes -> bytes32
    // ================================================================

    function packToEVMBool(bytes memory packed) internal pure returns (bytes32 result) {
        assembly {
            let len := mload(packed)
            let ptr := add(packed, 32)

            // Must be exactly 3 bytes
            if iszero(eq(len, 3)) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }

            let hdr := mload(ptr)
            let b0 := byte(0, hdr)
            let b1 := byte(1, hdr)
            let b2 := byte(2, hdr)

            // Check version byte 0x05
            if iszero(eq(b0, 0x05)) {
                mstore(0, shl(224, 0xe51a2409)) // InvalidVersionByte(uint8)
                mstore(4, b0)
                revert(0, 36)
            }

            // Check node tag 0x03
            if iszero(eq(b1, 0x03)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x03)
                mstore(36, b1)
                revert(0, 68)
            }

            // 0x0A = true, 0x03 = false
            switch b2
            case 0x0A { result := 1 }
            case 0x03 { result := 0 }
            default {
                mstore(0, shl(224, 0xb8ff4ada)) // InvalidBoolTag(uint8)
                mstore(4, b2)
                revert(0, 36)
            }
        }
    }

    // ================================================================
    // Bool: pack / unpack
    // ================================================================

    /// @notice Encode bool as Michelson PACK bytes using assembly.
    function packBool(bool v) internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            mstore(result, 3) // length = 3
            let ptr := add(result, 32)
            mstore8(ptr, 0x05)
            mstore8(add(ptr, 1), 0x03)
            switch v
            case 1 { mstore8(add(ptr, 2), 0x0A) }
            default { mstore8(add(ptr, 2), 0x03) }
            mstore(0x40, add(ptr, 32)) // update FMP (aligned)
        }
    }

    /// @notice Decode Michelson PACK bytes to bool using assembly.
    function unpackBool(bytes memory packed) internal pure returns (bool result) {
        assembly {
            let len := mload(packed)
            if iszero(eq(len, 3)) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }
            let hdr := mload(add(packed, 32))
            let b0 := byte(0, hdr)
            let b1 := byte(1, hdr)
            let b2 := byte(2, hdr)
            if iszero(eq(b0, 0x05)) {
                mstore(0, shl(224, 0xe51a2409)) // InvalidVersionByte(uint8)
                mstore(4, b0)
                revert(0, 36)
            }
            if iszero(eq(b1, 0x03)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x03)
                mstore(36, b1)
                revert(0, 68)
            }
            switch b2
            case 0x0A { result := 1 }
            case 0x03 { result := 0 }
            default {
                mstore(0, shl(224, 0xb8ff4ada)) // InvalidBoolTag(uint8)
                mstore(4, b2)
                revert(0, 36)
            }
        }
    }

    // ================================================================
    // Unit: pack / unpack
    // ================================================================

    /// @notice Encode unit as Michelson PACK bytes using assembly.
    function packUnit() internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            mstore(result, 3) // length = 3
            let ptr := add(result, 32)
            mstore8(ptr, 0x05)
            mstore8(add(ptr, 1), 0x03)
            mstore8(add(ptr, 2), 0x0B)
            mstore(0x40, add(ptr, 32)) // update FMP (aligned)
        }
    }

    /// @notice Decode Michelson PACK bytes as unit using assembly.
    function unpackUnit(bytes memory packed) internal pure {
        assembly {
            let len := mload(packed)
            if iszero(eq(len, 3)) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }
            let hdr := mload(add(packed, 32))
            if iszero(eq(byte(0, hdr), 0x05)) {
                mstore(0, shl(224, 0xe51a2409)) // InvalidVersionByte(uint8)
                mstore(4, byte(0, hdr))
                revert(0, 36)
            }
            if iszero(eq(byte(1, hdr), 0x03)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x03)
                mstore(36, byte(1, hdr))
                revert(0, 68)
            }
            if iszero(eq(byte(2, hdr), 0x0B)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x0B)
                mstore(36, byte(2, hdr))
                revert(0, 68)
            }
        }
    }

    // ================================================================
    // String: pack / unpack
    // ================================================================

    /// @notice Encode string as Michelson PACK bytes using assembly.
    function packString(string memory s) internal pure returns (bytes memory result) {
        assembly {
            let sLen := mload(s)
            let sData := add(s, 32)

            // Check length fits in uint32
            if gt(sLen, 0xFFFFFFFF) {
                mstore(0, shl(224, 0x44dddea2)) // IntOverflow()
                revert(0, 4)
            }

            // Total length = 2 (header) + 4 (length prefix) + sLen
            let totalLen := add(6, sLen)

            result := mload(0x40)
            mstore(result, totalLen) // set bytes length
            let ptr := add(result, 32)

            // Write header: 0x05 0x01
            mstore8(ptr, 0x05)
            mstore8(add(ptr, 1), 0x01)

            // Write big-endian uint32 length
            mstore8(add(ptr, 2), shr(24, sLen))
            mstore8(add(ptr, 3), and(shr(16, sLen), 0xFF))
            mstore8(add(ptr, 4), and(shr(8, sLen), 0xFF))
            mstore8(add(ptr, 5), and(sLen, 0xFF))

            // Copy string data using word-sized copies
            let dst := add(ptr, 6)
            let src := sData
            let remaining := sLen

            for {} gt(remaining, 31) {} {
                mstore(dst, mload(src))
                dst := add(dst, 32)
                src := add(src, 32)
                remaining := sub(remaining, 32)
            }
            // Copy remaining bytes (last partial word)
            if gt(remaining, 0) {
                let mask := sub(shl(mul(sub(32, remaining), 8), 1), 1)
                let srcWord := mload(src)
                let dstWord := mload(dst)
                mstore(dst, or(and(srcWord, not(mask)), and(dstWord, mask)))
            }

            // Update free memory pointer (round up to 32-byte boundary)
            mstore(0x40, and(add(add(ptr, totalLen), 31), not(31)))
        }
    }

    /// @notice Decode Michelson PACK bytes to string using assembly.
    function unpackString(bytes memory packed) internal pure returns (string memory result) {
        assembly {
            let pLen := mload(packed)
            let pPtr := add(packed, 32)

            // Minimum: 2 (header) + 4 (length) = 6
            if lt(pLen, 6) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }

            let hdr := mload(pPtr)

            // Check version byte 0x05
            if iszero(eq(byte(0, hdr), 0x05)) {
                mstore(0, shl(224, 0xe51a2409)) // InvalidVersionByte(uint8)
                mstore(4, byte(0, hdr))
                revert(0, 36)
            }

            // Check node tag 0x01 (string)
            if iszero(eq(byte(1, hdr), 0x01)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x01)
                mstore(36, byte(1, hdr))
                revert(0, 68)
            }

            // Read big-endian uint32 length from bytes 2..5
            let sLen := or(or(or(
                shl(24, byte(2, hdr)),
                shl(16, byte(3, hdr))),
                shl(8, byte(4, hdr))),
                byte(5, hdr))

            // Validate total length
            if iszero(eq(pLen, add(6, sLen))) {
                mstore(0, shl(224, 0xc3e44a73)) // TrailingBytes(uint256,uint256)
                mstore(4, add(6, sLen))
                mstore(36, pLen)
                revert(0, 68)
            }

            // Allocate result string
            result := mload(0x40)
            mstore(result, sLen) // set string length
            let dst := add(result, 32)
            let src := add(pPtr, 6)
            let remaining := sLen

            // Word-sized copy
            for {} gt(remaining, 31) {} {
                mstore(dst, mload(src))
                dst := add(dst, 32)
                src := add(src, 32)
                remaining := sub(remaining, 32)
            }
            // Copy remaining bytes
            if gt(remaining, 0) {
                let mask := sub(shl(mul(sub(32, remaining), 8), 1), 1)
                let srcWord := mload(src)
                let dstWord := mload(dst)
                mstore(dst, or(and(srcWord, not(mask)), and(dstWord, mask)))
            }

            // Update free memory pointer
            mstore(0x40, and(add(add(add(result, 32), sLen), 31), not(31)))
        }
    }

    // ================================================================
    // Mutez: pack / unpack (delegates to nat + bounds check)
    // ================================================================

    /// @notice Encode mutez as Michelson PACK bytes using assembly.
    function packMutez(uint64 v) internal pure returns (bytes memory) {
        return packNat(uint256(v));
    }

    /// @notice Decode Michelson PACK bytes to mutez using assembly.
    function unpackMutez(bytes memory packed) internal pure returns (uint64) {
        uint256 val = unpackNat(packed);
        assembly {
            // mutez is bounded to 0 .. 2^63 - 1
            if gt(val, 9223372036854775807) {
                mstore(0, shl(224, 0x44dddea2)) // IntOverflow()
                revert(0, 4)
            }
        }
        return uint64(val);
    }

    // ================================================================
    // Timestamp: pack / unpack (delegates to int + bounds check)
    // ================================================================

    /// @notice Encode timestamp as Michelson PACK bytes using assembly.
    function packTimestamp(int64 v) internal pure returns (bytes memory) {
        return packInt(int256(v));
    }

    /// @notice Decode Michelson PACK bytes to timestamp using assembly.
    function unpackTimestamp(bytes memory packed) internal pure returns (int64) {
        int256 val = unpackInt(packed);
        assembly {
            // timestamp is bounded to -2^63 .. 2^63 - 1
            if or(slt(val, sub(0, 9223372036854775808)), sgt(val, 9223372036854775807)) {
                mstore(0, shl(224, 0x44dddea2)) // IntOverflow()
                revert(0, 4)
            }
        }
        return int64(val);
    }

    // ================================================================
    // Bytes: pack / unpack (delegate to spec -- simple concat)
    // ================================================================

    function packBytes(bytes memory data) internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.bytes_(data));
    }
    function unpackBytes(bytes memory packed) internal pure returns (bytes memory) {
        return MichelsonSpec.toBytes(MichelsonSpec.unpack(packed));
    }

    // ================================================================
    // Address, Key_hash, Key, Signature, Chain_id, Contract
    // (all delegate to packBytes/unpackBytes)
    // ================================================================

    function packAddress(bytes memory addr) internal pure returns (bytes memory) {
        return packBytes(addr);
    }
    function unpackAddress(bytes memory packed) internal pure returns (bytes memory) {
        return unpackBytes(packed);
    }
    function packKeyHash(bytes memory kh) internal pure returns (bytes memory) {
        return packBytes(kh);
    }
    function unpackKeyHash(bytes memory packed) internal pure returns (bytes memory) {
        return unpackBytes(packed);
    }
    function packKey(bytes memory k) internal pure returns (bytes memory) {
        return packBytes(k);
    }
    function unpackKey(bytes memory packed) internal pure returns (bytes memory) {
        return unpackBytes(packed);
    }
    function packSignature(bytes memory sig) internal pure returns (bytes memory) {
        return packBytes(sig);
    }
    function unpackSignature(bytes memory packed) internal pure returns (bytes memory) {
        return unpackBytes(packed);
    }
    function packChainId(bytes memory cid) internal pure returns (bytes memory) {
        return packBytes(cid);
    }
    function unpackChainId(bytes memory packed) internal pure returns (bytes memory) {
        return unpackBytes(packed);
    }
    function packContract(bytes memory data) internal pure returns (bytes memory) {
        return packBytes(data);
    }
    function unpackContract(bytes memory packed) internal pure returns (bytes memory) {
        return unpackBytes(packed);
    }

    // ================================================================
    // Composite types: encode (delegate to spec)
    // ================================================================

    function pair(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        return MichelsonSpec.pair(a, b);
    }
    function left(bytes memory a) internal pure returns (bytes memory) {
        return MichelsonSpec.left(a);
    }
    function right(bytes memory b) internal pure returns (bytes memory) {
        return MichelsonSpec.right(b);
    }
    function some(bytes memory a) internal pure returns (bytes memory) {
        return MichelsonSpec.some(a);
    }
    function none() internal pure returns (bytes memory) {
        return MichelsonSpec.none();
    }
    function list(bytes[] memory items) internal pure returns (bytes memory) {
        return MichelsonSpec.list(items);
    }
    function elt(bytes memory k, bytes memory v) internal pure returns (bytes memory) {
        return MichelsonSpec.elt(k, v);
    }
    function map(bytes[] memory elts) internal pure returns (bytes memory) {
        return MichelsonSpec.map(elts);
    }
    function set(bytes[] memory items) internal pure returns (bytes memory) {
        return MichelsonSpec.set(items);
    }

    // ================================================================
    // Composite types: pack (delegate to spec)
    // ================================================================

    function packPair(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.pair(a, b));
    }
    function packLeft(bytes memory a) internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.left(a));
    }
    function packRight(bytes memory b) internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.right(b));
    }
    function packSome(bytes memory a) internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.some(a));
    }
    function packNone() internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.none());
    }
    function packList(bytes[] memory items) internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.list(items));
    }
    function packMap(bytes[] memory elts) internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.map(elts));
    }
    function packSet(bytes[] memory items) internal pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.set(items));
    }

    // ================================================================
    // Composite types: unpack (delegate to spec)
    // ================================================================

    function unpackPair(bytes memory packed) internal pure returns (bytes memory a, bytes memory b) {
        return MichelsonSpec.toPair(MichelsonSpec.unpack(packed));
    }
    function unpackOr(bytes memory packed) internal pure returns (bool isLeft, bytes memory value) {
        return MichelsonSpec.toOr(MichelsonSpec.unpack(packed));
    }
    function unpackOption(bytes memory packed) internal pure returns (bool isSome, bytes memory value) {
        return MichelsonSpec.toOption(MichelsonSpec.unpack(packed));
    }
    function unpackList(bytes memory packed) internal pure returns (bytes memory payload) {
        return MichelsonSpec.toList(MichelsonSpec.unpack(packed));
    }
    function unpackMap(bytes memory packed) internal pure returns (bytes memory payload) {
        return MichelsonSpec.toMap(MichelsonSpec.unpack(packed));
    }
    function unpackSet(bytes memory packed) internal pure returns (bytes memory payload) {
        return MichelsonSpec.toSet(MichelsonSpec.unpack(packed));
    }
}
