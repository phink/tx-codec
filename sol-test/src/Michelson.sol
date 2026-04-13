// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Assembly-optimized Michelson PACK encoders/decoders.
/// @dev Must produce identical results to MichelsonSpec (the IR-generated spec).
///      Differential fuzz tests enforce equivalence (96 asm-diff + 330 total).
///      Each public function is a single monolithic assembly block with comments
///      marking correspondence to the IR-generated MichelsonSpec functions.
///      MichelsonSpec is fully generated from the SolStmt IR transpiler (all 52 functions).
///
///      API: combinator style only.
///        Encoders build inner Micheline (no 0x05): nat(), int_(), bool_(), ...
///        Decoders read inner Micheline (no 0x05):  toNat(), toInt(), toBool(), ...
///        pack()/unpack() handle the 0x05 version byte.
///        Usage: pack(nat(42)), toNat(unpack(packed))
library Michelson {

    // ================================================================
    // Error declarations (needed by inlined Solidity functions below)
    // ================================================================

    error InvalidVersionByte(uint8 got);
    error UnexpectedNodeTag(uint8 expected, uint8 got);
    error IntOverflow();
    error InputTruncated();
    error TrailingBytes(uint256 consumed, uint256 total);

    // ================================================================
    // 0x05 handling: pack / unpack
    // ================================================================

    // -- Corresponds to MichelsonSpec.pack --
    function pack(bytes memory micheline) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"05", micheline);
    }

    // -- Corresponds to MichelsonSpec.unpack --
    function unpack(bytes memory packed) internal pure returns (bytes memory) {
        if ((packed.length < 1)) {
            revert InputTruncated();
        }
        if ((uint8(packed[0]) != 0x05)) {
            revert InvalidVersionByte(uint8(packed[0]));
        }
        return _slice(packed, 1, (packed.length - 1));
    }

    // ================================================================
    // Decoders (read inner Micheline, no 0x05)
    // ================================================================

    /// @notice Decode Micheline bytes to uint256 using assembly.
    /// @dev Expects raw Micheline (after unpack), not PACK bytes.
    function toNat(bytes memory micheline) internal pure returns (uint256 value) {
        assembly {
            let len := mload(micheline)
            let ptr := add(micheline, 32)

            // -- Corresponds to MichelsonSpec.toNat (node tag 0x00 check, length >= 2)
            //    micheline needs >= 2 bytes (0x00 + >=1 zarith byte).
            if lt(len, 2) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }
            let hdr := mload(ptr)
            let b0 := byte(0, hdr)
            if iszero(eq(b0, 0x00)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x00)
                mstore(36, b0)
                revert(0, 68)
            }

            // -- Corresponds to MichelsonSpec._decodeZarithNat(micheline, 1) --
            let offset := 1
            let remaining := sub(len, offset)
            if lt(remaining, 1) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated
                revert(0, 4)
            }

            let first := byte(0, mload(add(ptr, offset)))
            let newOffset := 0

            switch lt(first, 64)
            case 1 {
                // first < 64: single byte positive -- spec returns (first, offset + 1)
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
                    value := add(and(first, 0x3f), tailValue)
                }
            }

            // -- Corresponds to MichelsonSpec.toNat: trailing bytes check --
            if iszero(eq(newOffset, len)) {
                mstore(0, shl(224, 0xc3e44a73)) // TrailingBytes(uint256,uint256)
                mstore(4, newOffset)
                mstore(36, len)
                revert(0, 68)
            }
        }
    }

    /// @notice Decode Micheline bytes to int256 using assembly.
    /// @dev Expects raw Micheline (after unpack), not PACK bytes.
    function toInt(bytes memory micheline) internal pure returns (int256 value) {
        assembly {
            let len := mload(micheline)
            let ptr := add(micheline, 32)

            // -- Corresponds to MichelsonSpec.toInt (node tag 0x00 check, length >= 2)
            if lt(len, 2) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }
            let hdr := mload(ptr)
            let b0 := byte(0, hdr)
            if iszero(eq(b0, 0x00)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x00)
                mstore(36, b0)
                revert(0, 68)
            }

            // -- Corresponds to MichelsonSpec._decodeZarithInt(micheline, 1) --
            let offset := 1
            let remaining := sub(len, offset)
            if lt(remaining, 1) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated
                revert(0, 4)
            }

            let first := byte(0, mload(add(ptr, offset)))
            let newOffset := 0

            switch lt(first, 64)
            case 1 {
                // first < 64: positive single-byte -- spec: int256(first)
                value := first
                newOffset := add(offset, 1)
            }
            default {
                switch lt(first, 128)
                case 1 {
                    // 64 <= first < 128: negative single-byte
                    if eq(first, 64) {
                        mstore(0, shl(224, 0x7c1f7fe8)) // NegativeZero
                        revert(0, 4)
                    }
                    value := sub(0, sub(first, 64))
                    newOffset := add(offset, 1)
                }
                default {
                    // first >= 128: multi-byte
                    let negative := gt(first, 191)
                    let low6 := and(first, 0x3f)

                    // -- Corresponds to MichelsonSpec._decodeZarithTail(data, offset+1, 6) --
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

                    let absValue := add(low6, tailValue)

                    // -- Corresponds to MichelsonSpec._decodeZarithInt: sign handling --
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
            if iszero(eq(newOffset, len)) {
                mstore(0, shl(224, 0xc3e44a73)) // TrailingBytes(uint256,uint256)
                mstore(4, newOffset)
                mstore(36, len)
                revert(0, 68)
            }
        }
    }

    /// @notice Decode Micheline bytes to bool using assembly.
    function toBool(bytes memory micheline) internal pure returns (bool result) {
        assembly {
            let len := mload(micheline)
            if iszero(eq(len, 2)) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }
            let hdr := mload(add(micheline, 32))
            let b0 := byte(0, hdr)
            let b1 := byte(1, hdr)
            if iszero(eq(b0, 0x03)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x03)
                mstore(36, b0)
                revert(0, 68)
            }
            switch b1
            case 0x0A { result := 1 }
            case 0x03 { result := 0 }
            default {
                mstore(0, shl(224, 0xb8ff4ada)) // InvalidBoolTag(uint8)
                mstore(4, b1)
                revert(0, 36)
            }
        }
    }

    /// @notice Decode Micheline bytes as unit using assembly.
    function toUnit(bytes memory micheline) internal pure {
        assembly {
            let len := mload(micheline)
            if iszero(eq(len, 2)) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }
            let hdr := mload(add(micheline, 32))
            if iszero(eq(byte(0, hdr), 0x03)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x03)
                mstore(36, byte(0, hdr))
                revert(0, 68)
            }
            if iszero(eq(byte(1, hdr), 0x0B)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x0B)
                mstore(36, byte(1, hdr))
                revert(0, 68)
            }
        }
    }

    /// @notice Decode Micheline bytes to string using assembly.
    function toString(bytes memory micheline) internal pure returns (string memory result) {
        assembly {
            let pLen := mload(micheline)
            let pPtr := add(micheline, 32)

            // Minimum: 1 (tag) + 4 (length) = 5
            if lt(pLen, 5) {
                mstore(0, shl(224, 0x79fdd2ae)) // InputTruncated()
                revert(0, 4)
            }

            let hdr := mload(pPtr)

            // Check node tag 0x01 (string)
            if iszero(eq(byte(0, hdr), 0x01)) {
                mstore(0, shl(224, 0x1dd0dc36)) // UnexpectedNodeTag(uint8,uint8)
                mstore(4, 0x01)
                mstore(36, byte(0, hdr))
                revert(0, 68)
            }

            // Read big-endian uint32 length from bytes 1..4
            let sLen := or(or(or(
                shl(24, byte(1, hdr)),
                shl(16, byte(2, hdr))),
                shl(8, byte(3, hdr))),
                byte(4, hdr))

            // Validate total length
            if iszero(eq(pLen, add(5, sLen))) {
                mstore(0, shl(224, 0xc3e44a73)) // TrailingBytes(uint256,uint256)
                mstore(4, add(5, sLen))
                mstore(36, pLen)
                revert(0, 68)
            }

            // Allocate result string
            result := mload(0x40)
            mstore(result, sLen) // set string length
            let dst := add(result, 32)
            let src := add(pPtr, 5)
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

    // -- Corresponds to MichelsonSpec.toBytes --
    function toBytes(bytes memory micheline) internal pure returns (bytes memory) {
        if ((micheline.length < 5)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x0A)) {
            revert UnexpectedNodeTag(0x0A, uint8(micheline[0]));
        }
        uint256 len = uint256(uint8(micheline[1])) << 24
                    | uint256(uint8(micheline[2])) << 16
                    | uint256(uint8(micheline[3])) << 8
                    | uint256(uint8(micheline[4]));
        if ((micheline.length != (5 + len))) {
            revert TrailingBytes((5 + len), micheline.length);
        }
        return _slice(micheline, 5, len);
    }

    // -- Corresponds to MichelsonSpec.toMutez --
    function toMutez(bytes memory micheline) internal pure returns (uint64) {
        uint256 val = toNat(micheline);
        assembly {
            // mutez is bounded to 0 .. 2^63 - 1
            if gt(val, 9223372036854775807) {
                mstore(0, shl(224, 0x44dddea2)) // IntOverflow()
                revert(0, 4)
            }
        }
        return uint64(val);
    }

    // -- Corresponds to MichelsonSpec.toTimestamp --
    function toTimestamp(bytes memory micheline) internal pure returns (int64) {
        int256 val = toInt(micheline);
        assembly {
            // timestamp is bounded to -2^63 .. 2^63 - 1
            if or(slt(val, sub(0, 9223372036854775808)), sgt(val, 9223372036854775807)) {
                mstore(0, shl(224, 0x44dddea2)) // IntOverflow()
                revert(0, 4)
            }
        }
        return int64(val);
    }

    // -- Corresponds to MichelsonSpec.toPair --
    function toPair(bytes memory micheline) internal pure returns (bytes memory a, bytes memory b) {
        if ((micheline.length < 3)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x07)) {
            revert UnexpectedNodeTag(0x07, uint8(micheline[0]));
        }
        if ((uint8(micheline[1]) != 0x07)) {
            revert UnexpectedNodeTag(0x07, uint8(micheline[1]));
        }
        uint256 child1Size = _michelineNodeSize(micheline, 2, 0);
        a = _slice(micheline, 2, child1Size);
        b = _slice(micheline, (2 + child1Size), ((micheline.length - 2) - child1Size));
    }

    // -- Corresponds to MichelsonSpec.toOr --
    function toOr(bytes memory micheline) internal pure returns (bool isLeft, bytes memory value) {
        if ((micheline.length < 3)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x05)) {
            revert UnexpectedNodeTag(0x05, uint8(micheline[0]));
        }
        uint8 primTag = uint8(micheline[1]);
        if ((primTag == 0x05)) {
            isLeft = true;
        } else if ((primTag == 0x08)) {
            isLeft = false;
        } else revert UnexpectedNodeTag(0x05, primTag);
        value = _slice(micheline, 2, (micheline.length - 2));
    }

    // -- Corresponds to MichelsonSpec.toOption --
    function toOption(bytes memory micheline) internal pure returns (bool isSome, bytes memory value) {
        if ((micheline.length < 2)) {
            revert InputTruncated();
        }
        uint8 nodeTag = uint8(micheline[0]);
        if ((nodeTag == 0x05)) {
            if ((micheline.length < 3)) {
                revert InputTruncated();
            }
            if ((uint8(micheline[1]) != 0x09)) {
                revert UnexpectedNodeTag(0x09, uint8(micheline[1]));
            }
            isSome = true;
            value = _slice(micheline, 2, (micheline.length - 2));
        } else if ((nodeTag == 0x03)) {
            if ((uint8(micheline[1]) != 0x06)) {
                revert UnexpectedNodeTag(0x06, uint8(micheline[1]));
            }
            isSome = false;
            value = new bytes(0);
        } else revert UnexpectedNodeTag(0x05, nodeTag);
    }

    // -- Corresponds to MichelsonSpec.toList --
    function toList(bytes memory micheline) internal pure returns (bytes[] memory items) {
        bytes memory payload = _toListPayload(micheline);
        uint256 count = 0;
        uint256 offset = 0;
        while ((offset < payload.length)) {
            offset = (offset + _michelineNodeSize(payload, offset, 0));
            count = (count + 1);
        }
        items = new bytes[](count);
        offset = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 size = _michelineNodeSize(payload, offset, 0);
            items[i] = _slice(payload, offset, size);
            offset = (offset + size);
        }
    }

    // -- Corresponds to MichelsonSpec.toMap (same as toList) --
    function toMap(bytes memory micheline) internal pure returns (bytes[] memory) {
        return toList(micheline);
    }

    // -- Corresponds to MichelsonSpec.toSet (same as toList) --
    function toSet(bytes memory micheline) internal pure returns (bytes[] memory) {
        return toList(micheline);
    }

    // -- Corresponds to MichelsonSpec.toAddress (same as toBytes) --
    function toAddress(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    // -- Corresponds to MichelsonSpec.toKeyHash (same as toBytes) --
    function toKeyHash(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    // -- Corresponds to MichelsonSpec.toKey (same as toBytes) --
    function toKey(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    // -- Corresponds to MichelsonSpec.toSignature (same as toBytes) --
    function toSignature(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    // -- Corresponds to MichelsonSpec.toChainId (same as toBytes) --
    function toChainId(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    // -- Corresponds to MichelsonSpec.toContract (same as toBytes) --
    function toContract(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    // ================================================================
    // Encoders (build inner Micheline, no 0x05)
    // ================================================================

    /// @notice Encode uint256 as Micheline bytes (0x00 tag + zarith) using assembly.
    function nat(uint256 n) internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            let ptr := add(result, 32)

            // -- Corresponds to MichelsonSpec.nat(n) --
            // Micheline: 0x00 tag
            mstore8(ptr, 0x00)
            let len := 1

            // -- Corresponds to MichelsonSpec._encodeZarithNat(n) --
            let low6 := mod(n, 64)
            let rest := div(n, 64)

            switch rest
            case 0 {
                // rest == 0: single byte -- spec: uint8(low6)
                mstore8(add(ptr, len), low6)
                len := add(len, 1)
            }
            default {
                // rest >= 1: first byte = low6 + 128 -- spec: uint8(low6 + 128)
                mstore8(add(ptr, len), add(low6, 128))
                len := add(len, 1)

                // -- Corresponds to MichelsonSpec._encodeZarithTail(rest) --
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

    /// @notice Encode int256 as Micheline bytes (0x00 tag + zarith) using assembly.
    function int_(int256 v) internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            let ptr := add(result, 32)

            // -- Corresponds to MichelsonSpec.int_(v) --
            // Micheline: 0x00 tag
            mstore8(ptr, 0x00)
            let len := 1

            // -- Corresponds to MichelsonSpec._encodeZarithInt(v) --
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

    /// @notice Encode bool as Micheline bytes using assembly.
    function bool_(bool v) internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            mstore(result, 2) // length = 2
            let ptr := add(result, 32)
            mstore8(ptr, 0x03)
            switch v
            case 1 { mstore8(add(ptr, 1), 0x0A) }
            default { mstore8(add(ptr, 1), 0x03) }
            mstore(0x40, add(ptr, 32)) // update FMP (aligned)
        }
    }

    /// @notice Encode unit as Micheline bytes using assembly.
    function unit_() internal pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            mstore(result, 2) // length = 2
            let ptr := add(result, 32)
            mstore8(ptr, 0x03)
            mstore8(add(ptr, 1), 0x0B)
            mstore(0x40, add(ptr, 32)) // update FMP (aligned)
        }
    }

    /// @notice Encode string as Micheline bytes using assembly.
    function string_(string memory s) internal pure returns (bytes memory result) {
        assembly {
            let sLen := mload(s)
            let sData := add(s, 32)

            // Check length fits in uint32
            if gt(sLen, 0xFFFFFFFF) {
                mstore(0, shl(224, 0x44dddea2)) // IntOverflow()
                revert(0, 4)
            }

            // Total length = 1 (tag) + 4 (length prefix) + sLen
            let totalLen := add(5, sLen)

            result := mload(0x40)
            mstore(result, totalLen) // set bytes length
            let ptr := add(result, 32)

            // Write tag: 0x01
            mstore8(ptr, 0x01)

            // Write big-endian uint32 length
            mstore8(add(ptr, 1), shr(24, sLen))
            mstore8(add(ptr, 2), and(shr(16, sLen), 0xFF))
            mstore8(add(ptr, 3), and(shr(8, sLen), 0xFF))
            mstore8(add(ptr, 4), and(sLen, 0xFF))

            // Copy string data using word-sized copies
            let dst := add(ptr, 5)
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

    // -- Corresponds to MichelsonSpec.bytes_ --
    function bytes_(bytes memory data) internal pure returns (bytes memory) {
        if ((data.length > type(uint32).max)) {
            revert IntOverflow();
        }
        return abi.encodePacked(hex"0a", bytes4(uint32(data.length)), data);
    }

    // -- Corresponds to MichelsonSpec.pair --
    function pair(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(7), uint8(7), a, b);
    }

    // -- Corresponds to MichelsonSpec.left --
    function left(bytes memory a) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), uint8(5), a);
    }

    // -- Corresponds to MichelsonSpec.right --
    function right(bytes memory b) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), uint8(8), b);
    }

    // -- Corresponds to MichelsonSpec.some --
    function some(bytes memory a) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), uint8(9), a);
    }

    // -- Corresponds to MichelsonSpec.none --
    function none() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(3), uint8(6));
    }

    // -- Corresponds to MichelsonSpec.list --
    function list(bytes[] memory items) internal pure returns (bytes memory) {
        bytes memory payload;
        for (uint256 i = 0; i < items.length; i++) {
            payload = abi.encodePacked(payload, items[i]);
        }
        return abi.encodePacked(hex"02", bytes4(uint32(payload.length)), payload);
    }

    // -- Corresponds to MichelsonSpec.elt --
    function elt(bytes memory k, bytes memory v) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(7), uint8(4), k, v);
    }

    // -- Corresponds to MichelsonSpec.map --
    function map(bytes[] memory elts) internal pure returns (bytes memory) {
        return list(elts);
    }

    // -- Corresponds to MichelsonSpec.set --
    function set(bytes[] memory items) internal pure returns (bytes memory) {
        return list(items);
    }

    // -- Corresponds to MichelsonSpec.address_ (same as bytes_) --
    function address_(bytes memory addr) internal pure returns (bytes memory) {
        return bytes_(addr);
    }

    // -- Corresponds to MichelsonSpec.keyHash (same as bytes_) --
    function keyHash(bytes memory kh) internal pure returns (bytes memory) {
        return bytes_(kh);
    }

    // -- Corresponds to MichelsonSpec.key (same as bytes_) --
    function key(bytes memory k) internal pure returns (bytes memory) {
        return bytes_(k);
    }

    // -- Corresponds to MichelsonSpec.signature_ (same as bytes_) --
    function signature_(bytes memory sig) internal pure returns (bytes memory) {
        return bytes_(sig);
    }

    // -- Corresponds to MichelsonSpec.chainId (same as bytes_) --
    function chainId(bytes memory cid) internal pure returns (bytes memory) {
        return bytes_(cid);
    }

    // -- Corresponds to MichelsonSpec.contract_ (same as bytes_) --
    function contract_(bytes memory data) internal pure returns (bytes memory) {
        return bytes_(data);
    }

    // ================================================================
    // Optimized packToEVMNat / packToEVMInt / packToEVMBool
    // ================================================================

    function packToEVMNat(bytes memory packed) internal pure returns (bytes32) {
        return bytes32(toNat(unpack(packed)));
    }

    function packToEVMInt(bytes memory packed) internal pure returns (bytes32) {
        return bytes32(uint256(toInt(unpack(packed))));
    }

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
    // Private helpers (inlined from MichelsonSpec)
    // ================================================================

    // -- Corresponds to MichelsonSpec._slice --
    function _slice(bytes memory data, uint256 start, uint256 len) private pure returns (bytes memory result) {
        result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[(start + i)];
        }
    }

    // -- Corresponds to MichelsonSpec._michelineNodeSize --
    function _michelineNodeSize(bytes memory data, uint256 offset, uint256 depth) private pure returns (uint256) {
        if ((depth > 64)) {
            revert InputTruncated();
        }
        if ((offset >= data.length)) {
            revert InputTruncated();
        }
        uint8 tag = uint8(data[offset]);
        if ((tag == 0x00)) {
            uint256 i = (offset + 1);
            while ((i < data.length)) {
                if ((uint8(data[i]) < 128)) {
                    return ((i - offset) + 1);
                }
                i = (i + 1);
            }
            revert InputTruncated();
        } else         if ((((tag == 0x01) || (tag == 0x02)) || (tag == 0x0A))) {
            if (((offset + 5) > data.length)) {
                revert InputTruncated();
            }
            uint256 len = uint256(uint8(data[(offset + 1)])) << 24
                    | uint256(uint8(data[(offset + 2)])) << 16
                    | uint256(uint8(data[(offset + 3)])) << 8
                    | uint256(uint8(data[(offset + 4)]));
            if ((((offset + 5) + len) > data.length)) {
                revert InputTruncated();
            }
            return (5 + len);
        } else         if ((tag == 0x03)) {
            return 2;
        } else         if ((tag == 0x05)) {
            uint256 childSize = _michelineNodeSize(data, (offset + 2), (depth + 1));
            return (2 + childSize);
        } else         if ((tag == 0x07)) {
            uint256 child1Size = _michelineNodeSize(data, (offset + 2), (depth + 1));
            uint256 child2Size = _michelineNodeSize(data, ((offset + 2) + child1Size), (depth + 1));
            return ((2 + child1Size) + child2Size);
        } else         revert InputTruncated();
    }

    // -- Corresponds to MichelsonSpec._toListPayload --
    function _toListPayload(bytes memory micheline) private pure returns (bytes memory payload) {
        if ((micheline.length < 5)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x02)) {
            revert UnexpectedNodeTag(0x02, uint8(micheline[0]));
        }
        uint256 len = uint256(uint8(micheline[1])) << 24
                    | uint256(uint8(micheline[2])) << 16
                    | uint256(uint8(micheline[3])) << 8
                    | uint256(uint8(micheline[4]));
        if ((micheline.length != (5 + len))) {
            revert TrailingBytes((5 + len), micheline.length);
        }
        payload = _slice(micheline, 5, len);
    }
}
