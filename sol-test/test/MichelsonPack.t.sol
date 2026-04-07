// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MichelsonSpec.sol";

contract MichelsonHarness {
    function packNat(uint256 n) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.nat(n)); }
    function unpackNat(bytes memory packed) external pure returns (uint256) { return MichelsonSpec.toNat(MichelsonSpec.unpack(packed)); }
    function packInt(int256 v) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.int_(v)); }
    function unpackInt(bytes memory packed) external pure returns (int256) { return MichelsonSpec.toInt(MichelsonSpec.unpack(packed)); }
    function packBool(bool v) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bool_(v)); }
    function unpackBool(bytes memory packed) external pure returns (bool) { return MichelsonSpec.toBool(MichelsonSpec.unpack(packed)); }
    function packUnit() external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.unit_()); }
    function unpackUnit(bytes memory packed) external pure { MichelsonSpec.toUnit(MichelsonSpec.unpack(packed)); }
    function packString(string memory s) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.string_(s)); }
    function unpackString(bytes memory packed) external pure returns (string memory) { return MichelsonSpec.toString(MichelsonSpec.unpack(packed)); }
    function packBytes(bytes memory data) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bytes_(data)); }
    function unpackBytes(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toBytes(MichelsonSpec.unpack(packed)); }
    function packMutez(uint64 v) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.nat(uint256(v))); }
    function unpackMutez(bytes memory packed) external pure returns (uint64) { return MichelsonSpec.toMutez(MichelsonSpec.unpack(packed)); }
    function packTimestamp(int64 v) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.int_(int256(v))); }
    function unpackTimestamp(bytes memory packed) external pure returns (int64) { return MichelsonSpec.toTimestamp(MichelsonSpec.unpack(packed)); }
}

contract MichelsonNatTest is Test {
    MichelsonHarness h;

    function setUp() public {
        h = new MichelsonHarness();
    }

    // Known vectors
    function test_packNat_0() public view { assertEq(h.packNat(0), hex"050000"); }
    function test_packNat_1() public view { assertEq(h.packNat(1), hex"050001"); }
    function test_packNat_42() public view { assertEq(h.packNat(42), hex"05002a"); }
    function test_packNat_63() public view { assertEq(h.packNat(63), hex"05003f"); }
    function test_packNat_64() public view { assertEq(h.packNat(64), hex"05008001"); }
    function test_packNat_127() public view { assertEq(h.packNat(127), hex"0500bf01"); }
    function test_packNat_128() public view { assertEq(h.packNat(128), hex"05008002"); }
    function test_packNat_256() public view { assertEq(h.packNat(256), hex"05008004"); }
    function test_packNat_8192() public view { assertEq(h.packNat(8192), hex"0500808001"); }

    // Decode vectors
    function test_unpackNat_0() public view { assertEq(h.unpackNat(hex"050000"), 0); }
    function test_unpackNat_42() public view { assertEq(h.unpackNat(hex"05002a"), 42); }
    function test_unpackNat_64() public view { assertEq(h.unpackNat(hex"05008001"), 64); }
    function test_unpackNat_128() public view { assertEq(h.unpackNat(hex"05008002"), 128); }

    // Fuzz roundtrip
    function testFuzz_roundtrip_nat(uint256 n) public view {
        assertEq(h.unpackNat(h.packNat(n)), n);
    }

    // Edge cases
    function test_packNat_maxUint256() public view {
        assertEq(h.unpackNat(h.packNat(type(uint256).max)), type(uint256).max);
    }

    function test_packNat_powers_of_two() public view {
        for (uint256 i = 0; i < 256; i++) {
            uint256 n = 1 << i;
            assertEq(h.unpackNat(h.packNat(n)), n);
        }
    }

    function test_packNat_single_byte_range() public view {
        for (uint256 i = 0; i < 64; i++) {
            assertEq(h.packNat(i).length, 3);
        }
        assertEq(h.packNat(64).length, 4);
    }

    // Invalid inputs
    function test_unpackNat_empty_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackNat(hex"");
    }

    function test_unpackNat_too_short_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackNat(hex"0500");
    }

    function test_unpackNat_wrong_version_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackNat(hex"060001");
    }

    function test_unpackNat_wrong_tag_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x00), uint8(0x01)));
        h.unpackNat(hex"050101");
    }

    function test_unpackNat_negative_zero_reverts() public {
        vm.expectRevert(MichelsonSpec.NatNegative.selector);
        h.unpackNat(hex"050040");
    }

    function test_unpackNat_negative_value_reverts() public {
        vm.expectRevert(MichelsonSpec.NatNegative.selector);
        h.unpackNat(hex"050041");
    }

    function test_unpackNat_trailing_zero_byte_reverts() public {
        vm.expectRevert(MichelsonSpec.TrailingZeroByte.selector);
        h.unpackNat(hex"05008000");
    }

    function test_unpackNat_truncated_continuation_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackNat(hex"050080");
    }
}

contract MichelsonIntTest is Test {
    MichelsonHarness h;

    function setUp() public {
        h = new MichelsonHarness();
    }

    // Known vectors (from kb.md)
    function test_packInt_0() public view { assertEq(h.packInt(0), hex"050000"); }
    function test_packInt_1() public view { assertEq(h.packInt(1), hex"050001"); }
    function test_packInt_42() public view { assertEq(h.packInt(42), hex"05002a"); }
    function test_packInt_neg1() public view { assertEq(h.packInt(-1), hex"050041"); }
    function test_packInt_neg64() public view { assertEq(h.packInt(-64), hex"0500c001"); }
    function test_packInt_63() public view { assertEq(h.packInt(63), hex"05003f"); }
    function test_packInt_64() public view { assertEq(h.packInt(64), hex"05008001"); }

    // Decode vectors
    function test_unpackInt_0() public view { assertEq(h.unpackInt(hex"050000"), 0); }
    function test_unpackInt_42() public view { assertEq(h.unpackInt(hex"05002a"), 42); }
    function test_unpackInt_neg1() public view { assertEq(h.unpackInt(hex"050041"), -1); }
    function test_unpackInt_neg64() public view { assertEq(h.unpackInt(hex"0500c001"), -64); }

    // Fuzz roundtrip
    function testFuzz_roundtrip_int(int256 v) public view {
        assertEq(h.unpackInt(h.packInt(v)), v);
    }

    // Edge cases
    function test_packInt_maxInt256() public view {
        assertEq(h.unpackInt(h.packInt(type(int256).max)), type(int256).max);
    }

    function test_packInt_minInt256() public view {
        assertEq(h.unpackInt(h.packInt(type(int256).min)), type(int256).min);
    }

    function test_packInt_single_byte_positive_range() public view {
        for (int256 i = 0; i < 64; i++) {
            assertEq(h.packInt(i).length, 3);
        }
    }

    function test_packInt_single_byte_negative_range() public view {
        for (int256 i = -1; i >= -63; i--) {
            assertEq(h.packInt(i).length, 3);
        }
    }

    // Nat encoded values should decode as int too (same bytes, positive)
    function test_nat_bytes_decode_as_int() public view {
        assertEq(h.unpackInt(hex"050000"), int256(0));
        assertEq(h.unpackInt(hex"05002a"), int256(42));
        assertEq(h.unpackInt(hex"05008001"), int256(64));
    }

    // Invalid inputs
    function test_unpackInt_negative_zero_reverts() public {
        vm.expectRevert(MichelsonSpec.NegativeZero.selector);
        h.unpackInt(hex"050040");
    }

    function test_unpackInt_trailing_zero_byte_reverts() public {
        vm.expectRevert(MichelsonSpec.TrailingZeroByte.selector);
        h.unpackInt(hex"0500c000");
    }

    function test_unpackInt_truncated_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackInt(hex"0500c0");
    }

    function test_unpackInt_empty_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackInt(hex"");
    }
}

contract MichelsonBoolTest is Test {
    MichelsonHarness h;
    function setUp() public { h = new MichelsonHarness(); }

    // Known vectors
    function test_packBool_true() public view { assertEq(h.packBool(true), hex"05030a"); }
    function test_packBool_false() public view { assertEq(h.packBool(false), hex"050303"); }

    // Decode
    function test_unpackBool_true() public view { assertTrue(h.unpackBool(hex"05030a")); }
    function test_unpackBool_false() public view { assertFalse(h.unpackBool(hex"050303")); }

    // Fuzz roundtrip
    function testFuzz_roundtrip_bool(bool v) public view {
        assertEq(h.unpackBool(h.packBool(v)), v);
    }

    // Invalid inputs
    function test_unpackBool_wrong_version() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackBool(hex"06030a");
    }

    function test_unpackBool_wrong_tag() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x03), uint8(0x00)));
        h.unpackBool(hex"05000a");
    }

    function test_unpackBool_invalid_prim() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidBoolTag.selector, uint8(0x0B)));
        h.unpackBool(hex"05030b");
    }

    function test_unpackBool_empty() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackBool(hex"");
    }

    function test_unpackBool_too_long() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackBool(hex"05030a00");
    }
}

contract MichelsonUnitTest is Test {
    MichelsonHarness h;
    function setUp() public { h = new MichelsonHarness(); }

    function test_packUnit() public view { assertEq(h.packUnit(), hex"05030b"); }

    function test_unpackUnit() public view { h.unpackUnit(hex"05030b"); }

    function test_unpackUnit_wrong_version() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackUnit(hex"06030b");
    }

    function test_unpackUnit_wrong_tag() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x03), uint8(0x00)));
        h.unpackUnit(hex"05000b");
    }

    function test_unpackUnit_wrong_prim() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x0B), uint8(0x0A)));
        h.unpackUnit(hex"05030a");
    }

    function test_unpackUnit_empty() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackUnit(hex"");
    }
}

contract MichelsonStringTest is Test {
    MichelsonHarness h;
    function setUp() public { h = new MichelsonHarness(); }

    // Known vectors
    function test_packString_empty() public view {
        assertEq(h.packString(""), hex"050100000000");
    }

    function test_packString_hello() public view {
        assertEq(h.packString("hello"), hex"05010000000568656c6c6f");
    }

    // Decode
    function test_unpackString_empty() public view {
        assertEq(h.unpackString(hex"050100000000"), "");
    }

    function test_unpackString_hello() public view {
        assertEq(h.unpackString(hex"05010000000568656c6c6f"), "hello");
    }

    // Fuzz roundtrip
    function testFuzz_roundtrip_string(string memory s) public view {
        assertEq(h.unpackString(h.packString(s)), s);
    }

    // Invalid inputs
    function test_unpackString_truncated_header() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackString(hex"0501");
    }

    function test_unpackString_wrong_version() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackString(hex"060100000000");
    }

    function test_unpackString_wrong_tag() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x01), uint8(0x00)));
        h.unpackString(hex"050000000000");
    }

    function test_unpackString_trailing_bytes() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.TrailingBytes.selector, uint256(5), uint256(6)));
        h.unpackString(hex"05010000000000");
    }

    function test_unpackString_length_too_large() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.TrailingBytes.selector, uint256(6), uint256(5)));
        h.unpackString(hex"050100000001");
    }
}

contract MichelsonMutezTest is Test {
    MichelsonHarness h;
    function setUp() public { h = new MichelsonHarness(); }

    // Known vectors: mutez uses nat encoding
    function test_packMutez_0() public view { assertEq(h.packMutez(0), hex"050000"); }
    function test_packMutez_1() public view { assertEq(h.packMutez(1), hex"050001"); }
    function test_packMutez_42() public view { assertEq(h.packMutez(42), hex"05002a"); }
    function test_packMutez_1000000() public view {
        assertEq(h.unpackMutez(h.packMutez(1000000)), 1000000);
    }

    // Decode vectors
    function test_unpackMutez_0() public view { assertEq(h.unpackMutez(hex"050000"), 0); }
    function test_unpackMutez_42() public view { assertEq(h.unpackMutez(hex"05002a"), 42); }

    // Fuzz roundtrip (bounded to valid mutez range: 0 .. 2^63 - 1)
    function testFuzz_roundtrip_mutez(uint64 v) public view {
        vm.assume(v <= type(uint64).max / 2);
        assertEq(h.unpackMutez(h.packMutez(v)), v);
    }

    // Edge cases
    function test_packMutez_maxValid() public view {
        uint64 maxMutez = type(uint64).max / 2; // 2^63 - 1
        assertEq(h.unpackMutez(h.packMutez(maxMutez)), maxMutez);
    }

    // Overflow: value > 2^63 - 1 should revert on unpack
    function test_unpackMutez_overflow_reverts() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.nat(uint256(type(uint64).max / 2) + 1));
        vm.expectRevert(MichelsonSpec.IntOverflow.selector);
        h.unpackMutez(packed);
    }

    function test_unpackMutez_large_nat_reverts() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.nat(type(uint256).max));
        vm.expectRevert(MichelsonSpec.IntOverflow.selector);
        h.unpackMutez(packed);
    }

    // Invalid inputs
    function test_unpackMutez_empty_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackMutez(hex"");
    }
}

contract MichelsonTimestampTest is Test {
    MichelsonHarness h;
    function setUp() public { h = new MichelsonHarness(); }

    // Known vectors: timestamp uses int encoding
    function test_packTimestamp_0() public view { assertEq(h.packTimestamp(0), hex"050000"); }
    function test_packTimestamp_1() public view { assertEq(h.packTimestamp(1), hex"050001"); }
    function test_packTimestamp_neg1() public view { assertEq(h.packTimestamp(-1), hex"050041"); }
    function test_packTimestamp_1000000() public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(1000000)), 1000000);
    }
    function test_packTimestamp_neg1000000() public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(-1000000)), -1000000);
    }

    // Decode vectors
    function test_unpackTimestamp_0() public view { assertEq(h.unpackTimestamp(hex"050000"), 0); }
    function test_unpackTimestamp_neg1() public view { assertEq(h.unpackTimestamp(hex"050041"), -1); }

    // Fuzz roundtrip
    function testFuzz_roundtrip_timestamp(int64 v) public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(v)), v);
    }

    // Edge cases
    function test_packTimestamp_maxInt64() public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(type(int64).max)), type(int64).max);
    }

    function test_packTimestamp_minInt64() public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(type(int64).min)), type(int64).min);
    }

    // Overflow: int value outside int64 range should revert on unpack
    function test_unpackTimestamp_overflow_positive_reverts() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.int_(int256(type(int64).max) + 1));
        vm.expectRevert(MichelsonSpec.IntOverflow.selector);
        h.unpackTimestamp(packed);
    }

    function test_unpackTimestamp_overflow_negative_reverts() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.int_(int256(type(int64).min) - 1));
        vm.expectRevert(MichelsonSpec.IntOverflow.selector);
        h.unpackTimestamp(packed);
    }

    // Invalid inputs
    function test_unpackTimestamp_empty_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackTimestamp(hex"");
    }
}
