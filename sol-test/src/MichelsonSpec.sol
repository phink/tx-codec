// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Auto-generated from verified Lean 4 specification via AST-based transpiler.
/// @dev Encodes/decodes Michelson PACK format.
///      Verified properties (in Lean 4, zero sorry):
///        - decode(encode(x)) = x   (left roundtrip)
///        - encode(decode(b)) = b   (right roundtrip, for canonical b)
///      API: MichelsonSpec.nat(42) builds raw Micheline, MichelsonSpec.pack(...) adds 0x05.
///
///      All functions are generated from the SolStmt IR (AST-transpiled or IR-constructed).
library MichelsonSpec {

    error InvalidVersionByte(uint8 got);
    error UnexpectedNodeTag(uint8 expected, uint8 got);
    error IntOverflow();
    error NatNegative();
    error NegativeZero();
    error TrailingZeroByte();
    error TrailingBytes(uint256 consumed, uint256 total);
    error InputTruncated();
    error InvalidBoolTag(uint8 got);
    error InvalidEncoding();

    // ================================================================
    // [transpiled] Zarith encoders — generated from Lean 4 equation lemmas
    // ================================================================

    function _encodeZarithTail(uint256 rest) private pure returns (bytes memory) {
        if ((rest == 0)) {
            return new bytes(0);
        } else {
            if ((rest < 128)) {
                return abi.encodePacked(uint8(rest));
            } else {
                return abi.encodePacked(uint8(((rest % 128) + 128)), _encodeZarithTail((rest / 128)));
            }
        }
    }

    function _encodeZarithNat(uint256 n) private pure returns (bytes memory) {
        uint256 low6 = (n % 64);
        uint256 rest = (n / 64);
        if ((rest >= 1)) {
            return abi.encodePacked(uint8((low6 + 128)), _encodeZarithTail(rest));
        } else {
            return abi.encodePacked(uint8(low6));
        }
    }

    function _encodeZarithInt(int256 z) private pure returns (bytes memory) {
        if ((z >= 0)) {
            uint256 n = uint256(z);
            return _encodeZarithNat(n);
        } else {
            unchecked {
                uint256 n = (uint256(-(z)) - 1);
                uint256 a = (n + 1);
                if ((a < 64)) {
                    return abi.encodePacked(uint8((a + 64)));
                } else {
                    return abi.encodePacked(uint8((((a % 64) + 64) + 128)), _encodeZarithTail((a / 64)));
                }
            }
        }
    }

    // ================================================================
    // [transpiled] Zarith decoders — generated from Lean 4 equation lemmas
    // ================================================================

    function _decodeZarithTail(bytes memory data, uint256 offset, uint256 shift) private pure returns (uint256 value, uint256 newOffset) {
        if ((offset < data.length)) {
            uint256 b = uint8(data[offset]);
            if ((b >= 128)) {
                (uint256 rv, uint256 newOff) = _decodeZarithTail(data, (offset + 1), (shift + 7));
                return ((((b % 128) * (2 ** shift)) + rv), newOff);
            } else {
                if ((b == 0)) {
                    revert TrailingZeroByte();
                } else {
                    return ((b * (2 ** shift)), (offset + 1));
                }
            }
        } else {
            revert InputTruncated();
        }
    }

    function _decodeZarithNat(bytes memory data, uint256 offset) private pure returns (uint256 value, uint256 newOffset) {
        if ((offset < data.length)) {
            uint256 first = uint8(data[offset]);
            if ((first >= 128)) {
                if ((first >= 192)) {
                    revert NatNegative();
                } else {
                    (uint256 tv, uint256 newOff) = _decodeZarithTail(data, (offset + 1), 6);
                    return (((first % 64) + tv), newOff);
                }
            } else {
                if ((first >= 64)) {
                    revert NatNegative();
                } else {
                    return (first, (offset + 1));
                }
            }
        } else {
            revert InputTruncated();
        }
    }

    function _decodeZarithInt(bytes memory data, uint256 offset) private pure returns (int256 value, uint256 newOffset) {
        if ((offset < data.length)) {
            uint256 first = uint8(data[offset]);
            if ((first < 64)) {
                return (int256(first), (offset + 1));
            } else {
                if ((first < 128)) {
                    if ((first == 64)) {
                        revert NegativeZero();
                    } else {
                        unchecked {
                            return (-(int256((first - 64))), (offset + 1));
                        }
                    }
                } else {
                    if ((first < 192)) {
                        (uint256 tv, uint256 newOff) = _decodeZarithTail(data, (offset + 1), 6);
                        return (int256(((first % 64) + tv)), newOff);
                    } else {
                        (uint256 tv, uint256 newOff) = _decodeZarithTail(data, (offset + 1), 6);
                        unchecked {
                            return (-(int256(((first % 64) + tv))), newOff);
                        }
                    }
                }
            }
        } else {
            revert InputTruncated();
        }
    }

    function _decodeUint32BE(bytes memory data, uint256 offset) private pure returns (uint256 value, uint256 newOffset) {
        if (((offset + 4) <= data.length)) {
            uint256 b0 = uint8(data[offset]);
            uint256 b1 = uint8(data[(offset + 1)]);
            uint256 b2 = uint8(data[(offset + 2)]);
            uint256 b3 = uint8(data[(offset + 3)]);
            return (((((b0 * 16777216) + (b1 * 65536)) + (b2 * 256)) + b3), (offset + 4));
        } else {
            revert InvalidEncoding();
        }
    }

    // ================================================================
    // [transpiled] Inner Micheline encoders — generated from Lean 4 definitions
    // ================================================================

    function nat(uint256 n) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0), _encodeZarithNat(n));
    }

    function int_(int256 v) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0), _encodeZarithInt(v));
    }

    function bool_(bool v) internal pure returns (bytes memory) {
        if (v) {
            return abi.encodePacked(uint8(3), uint8(10));
        } else {
            return abi.encodePacked(uint8(3), uint8(3));
        }
    }

    function pair(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(7), uint8(7), a, b);
    }

    function left(bytes memory a) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), uint8(5), a);
    }

    function right(bytes memory b) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), uint8(8), b);
    }

    function some(bytes memory a) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(5), uint8(9), a);
    }

    function elt(bytes memory k, bytes memory v) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(7), uint8(4), k, v);
    }

    function unit_() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(3), uint8(11));
    }

    function none() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(3), uint8(6));
    }

    // ================================================================
    // [IR] Encoding wrappers, decoders, helpers — constructed from SolStmt IR
    // ================================================================

    function pack(bytes memory micheline) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"05", micheline);
    }

    function unpack(bytes memory packed) internal pure returns (bytes memory) {
        if ((packed.length < 1)) {
            revert InputTruncated();
        }
        if ((uint8(packed[0]) != 0x05)) {
            revert InvalidVersionByte(uint8(packed[0]));
        }
        return _slice(packed, 1, (packed.length - 1));
    }

    function string_(string memory s) internal pure returns (bytes memory) {
        bytes memory raw = bytes(s);
        if ((raw.length > type(uint32).max)) {
            revert IntOverflow();
        }
        return abi.encodePacked(hex"01", bytes4(uint32(raw.length)), raw);
    }

    function bytes_(bytes memory data) internal pure returns (bytes memory) {
        if ((data.length > type(uint32).max)) {
            revert IntOverflow();
        }
        return abi.encodePacked(hex"0a", bytes4(uint32(data.length)), data);
    }

    function list(bytes[] memory items) internal pure returns (bytes memory) {
        bytes memory payload;
        for (uint256 i = 0; i < items.length; i++) {
            payload = abi.encodePacked(payload, items[i]);
        }
        return abi.encodePacked(hex"02", bytes4(uint32(payload.length)), payload);
    }

    function map(bytes[] memory elts) internal pure returns (bytes memory) {
        return list(elts);
    }

    function set(bytes[] memory items) internal pure returns (bytes memory) {
        return list(items);
    }

    function address_(bytes memory addr) internal pure returns (bytes memory) {
        return bytes_(addr);
    }

    function keyHash(bytes memory kh) internal pure returns (bytes memory) {
        return bytes_(kh);
    }

    function key(bytes memory k) internal pure returns (bytes memory) {
        return bytes_(k);
    }

    function signature_(bytes memory sig) internal pure returns (bytes memory) {
        return bytes_(sig);
    }

    function chainId(bytes4 id) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"0a", bytes4(uint32(4)), id);
    }

    function contract_(bytes memory addr, string memory ep) internal pure returns (bytes memory) {
        bytes memory epBytes = bytes(ep);
        if ((epBytes.length == 0)) {
            return bytes_(addr);
        } else {
            bytes memory combined = abi.encodePacked(addr, epBytes);
            return bytes_(combined);
        }
    }

    function toNat(bytes memory micheline) internal pure returns (uint256) {
        if ((micheline.length < 2)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x00)) {
            revert UnexpectedNodeTag(0x00, uint8(micheline[0]));
        }
        (uint256 value, uint256 consumed) = _decodeZarithNat(micheline, 1);
        if ((consumed != micheline.length)) {
            revert TrailingBytes(consumed, micheline.length);
        }
        return value;
    }

    function toInt(bytes memory micheline) internal pure returns (int256) {
        if ((micheline.length < 2)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x00)) {
            revert UnexpectedNodeTag(0x00, uint8(micheline[0]));
        }
        (int256 value, uint256 consumed) = _decodeZarithInt(micheline, 1);
        if ((consumed != micheline.length)) {
            revert TrailingBytes(consumed, micheline.length);
        }
        return value;
    }

    function toBool(bytes memory micheline) internal pure returns (bool) {
        if ((micheline.length != 2)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x03)) {
            revert UnexpectedNodeTag(0x03, uint8(micheline[0]));
        }
        uint8 tag = uint8(micheline[1]);
        if ((tag == 0x0A)) {
            return true;
        }
        if ((tag == 0x03)) {
            return false;
        }
        revert InvalidBoolTag(tag);
    }

    function toUnit(bytes memory micheline) internal pure {
        if ((micheline.length != 2)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x03)) {
            revert UnexpectedNodeTag(0x03, uint8(micheline[0]));
        }
        if ((uint8(micheline[1]) != 0x0B)) {
            revert UnexpectedNodeTag(0x0B, uint8(micheline[1]));
        }
    }

    function toString(bytes memory micheline) internal pure returns (string memory) {
        if ((micheline.length < 5)) {
            revert InputTruncated();
        }
        if ((uint8(micheline[0]) != 0x01)) {
            revert UnexpectedNodeTag(0x01, uint8(micheline[0]));
        }
        uint256 len = uint256(uint8(micheline[1])) << 24
                    | uint256(uint8(micheline[2])) << 16
                    | uint256(uint8(micheline[3])) << 8
                    | uint256(uint8(micheline[4]));
        if ((micheline.length != (5 + len))) {
            revert TrailingBytes((5 + len), micheline.length);
        }
        return string(_slice(micheline, 5, len));
    }

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

    function toMutez(bytes memory micheline) internal pure returns (uint64) {
        uint256 value = toNat(micheline);
        if ((value > (type(uint64).max / 2))) {
            revert IntOverflow();
        }
        return uint64(value);
    }

    function toTimestamp(bytes memory micheline) internal pure returns (int64) {
        int256 value = toInt(micheline);
        if (((value < type(int64).min) || (value > type(int64).max))) {
            revert IntOverflow();
        }
        return int64(value);
    }

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
        } else         if ((primTag == 0x08)) {
            isLeft = false;
        } else         revert UnexpectedNodeTag(0x05, primTag);
        value = _slice(micheline, 2, (micheline.length - 2));
    }

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
        } else         if ((nodeTag == 0x03)) {
            if ((uint8(micheline[1]) != 0x06)) {
                revert UnexpectedNodeTag(0x06, uint8(micheline[1]));
            }
            isSome = false;
            value = new bytes(0);
        } else         revert UnexpectedNodeTag(0x05, nodeTag);
    }

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

    function toMap(bytes memory micheline) internal pure returns (bytes[] memory) {
        return toList(micheline);
    }

    function toSet(bytes memory micheline) internal pure returns (bytes[] memory) {
        return toList(micheline);
    }

    function toAddress(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    function toKeyHash(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    function toKey(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    function toSignature(bytes memory micheline) internal pure returns (bytes memory) {
        return toBytes(micheline);
    }

    function toChainId(bytes memory micheline) internal pure returns (bytes4) {
        bytes memory data = toBytes(micheline);
        if ((data.length != 4)) {
            revert TrailingBytes(4, data.length);
        }
        return bytes4(data[0])
                    | (bytes4(data[1]) >> 8)
                    | (bytes4(data[2]) >> 16)
                    | (bytes4(data[3]) >> 24);
    }

    function toContract(bytes memory micheline) internal pure returns (bytes memory addr, bytes memory entrypoint) {
        bytes memory data = toBytes(micheline);
        // Binary address is 22 bytes; anything after is the entrypoint name
        if ((data.length < 22)) {
            addr = data;
            entrypoint = new bytes(0);
        } else {
            addr = _slice(data, 0, 22);
            entrypoint = _slice(data, 22, (data.length - 22));
        }
    }

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

    function _slice(bytes memory data, uint256 start, uint256 len) private pure returns (bytes memory result) {
        result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[(start + i)];
        }
    }
}
