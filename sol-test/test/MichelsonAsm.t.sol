// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Michelson.sol";
import "../src/MichelsonSpec.sol"; // for error selectors not declared in Michelson.sol

/// @dev Harness to expose Michelson (asm) library functions via external calls,
///      enabling vm.expectRevert and gas metering.
contract AsmHarness {
    // Scalar pack/unpack
    function packNat(uint256 n) external pure returns (bytes memory) { return Michelson.pack(Michelson.nat(n)); }
    function unpackNat(bytes memory packed) external pure returns (uint256) { return Michelson.toNat(Michelson.unpack(packed)); }
    function packInt(int256 v) external pure returns (bytes memory) { return Michelson.pack(Michelson.int_(v)); }
    function unpackInt(bytes memory packed) external pure returns (int256) { return Michelson.toInt(Michelson.unpack(packed)); }
    function packBool(bool v) external pure returns (bytes memory) { return Michelson.pack(Michelson.bool_(v)); }
    function unpackBool(bytes memory packed) external pure returns (bool) { return Michelson.toBool(Michelson.unpack(packed)); }
    function packUnit() external pure returns (bytes memory) { return Michelson.pack(Michelson.unit_()); }
    function unpackUnit(bytes memory packed) external pure { Michelson.toUnit(Michelson.unpack(packed)); }
    function packString(string memory s) external pure returns (bytes memory) { return Michelson.pack(Michelson.string_(s)); }
    function unpackString(bytes memory packed) external pure returns (string memory) { return Michelson.toString(Michelson.unpack(packed)); }
    function packBytes(bytes memory data) external pure returns (bytes memory) { return Michelson.pack(Michelson.bytes_(data)); }
    function unpackBytes(bytes memory packed) external pure returns (bytes memory) { return Michelson.toBytes(Michelson.unpack(packed)); }
    function packMutez(uint64 v) external pure returns (bytes memory) { return Michelson.pack(Michelson.nat(uint256(v))); }
    function unpackMutez(bytes memory packed) external pure returns (uint64) { return Michelson.toMutez(Michelson.unpack(packed)); }
    function packTimestamp(int64 v) external pure returns (bytes memory) { return Michelson.pack(Michelson.int_(int256(v))); }
    function unpackTimestamp(bytes memory packed) external pure returns (int64) { return Michelson.toTimestamp(Michelson.unpack(packed)); }

    // Address / key_hash / key / signature / chain_id / contract
    function packAddress(bytes memory addr) external pure returns (bytes memory) { return Michelson.pack(Michelson.address_(addr)); }
    function unpackAddress(bytes memory packed) external pure returns (bytes memory) { return Michelson.toAddress(Michelson.unpack(packed)); }
    function packKeyHash(bytes memory kh) external pure returns (bytes memory) { return Michelson.pack(Michelson.keyHash(kh)); }
    function unpackKeyHash(bytes memory packed) external pure returns (bytes memory) { return Michelson.toKeyHash(Michelson.unpack(packed)); }
    function packKey(bytes memory k) external pure returns (bytes memory) { return Michelson.pack(Michelson.key(k)); }
    function unpackKey(bytes memory packed) external pure returns (bytes memory) { return Michelson.toKey(Michelson.unpack(packed)); }
    function packSignature(bytes memory sig) external pure returns (bytes memory) { return Michelson.pack(Michelson.signature_(sig)); }
    function unpackSignature(bytes memory packed) external pure returns (bytes memory) { return Michelson.toSignature(Michelson.unpack(packed)); }
    function packChainId(bytes memory cid) external pure returns (bytes memory) { return Michelson.pack(Michelson.bytes_(cid)); }
    function unpackChainId(bytes memory packed) external pure returns (bytes memory) { return Michelson.toBytes(Michelson.unpack(packed)); }
    function packContract(bytes memory data) external pure returns (bytes memory) { return Michelson.pack(Michelson.bytes_(data)); }
    function unpackContract(bytes memory packed) external pure returns (bytes memory) { return Michelson.toBytes(Michelson.unpack(packed)); }

    // Composite helpers
    function nat(uint256 n) external pure returns (bytes memory) { return Michelson.nat(n); }
    function int_(int256 v) external pure returns (bytes memory) { return Michelson.int_(v); }
    function bool_(bool v) external pure returns (bytes memory) { return Michelson.bool_(v); }
    function string_(string memory s) external pure returns (bytes memory) { return Michelson.string_(s); }
    function bytes_(bytes memory data) external pure returns (bytes memory) { return Michelson.bytes_(data); }
    function pair(bytes memory a, bytes memory b) external pure returns (bytes memory) { return Michelson.pair(a, b); }
    function left(bytes memory a) external pure returns (bytes memory) { return Michelson.left(a); }
    function right(bytes memory b) external pure returns (bytes memory) { return Michelson.right(b); }
    function some(bytes memory a) external pure returns (bytes memory) { return Michelson.some(a); }
    function none() external pure returns (bytes memory) { return Michelson.none(); }
    function list(bytes[] memory items) external pure returns (bytes memory) { return Michelson.list(items); }
    function elt(bytes memory k, bytes memory v) external pure returns (bytes memory) { return Michelson.elt(k, v); }
    function map(bytes[] memory elts) external pure returns (bytes memory) { return Michelson.map(elts); }
    function set(bytes[] memory items) external pure returns (bytes memory) { return Michelson.set(items); }

    // Composite pack/unpack
    function packPair(bytes memory a, bytes memory b) external pure returns (bytes memory) { return Michelson.pack(Michelson.pair(a, b)); }
    function packLeft(bytes memory a) external pure returns (bytes memory) { return Michelson.pack(Michelson.left(a)); }
    function packRight(bytes memory b) external pure returns (bytes memory) { return Michelson.pack(Michelson.right(b)); }
    function packSome(bytes memory a) external pure returns (bytes memory) { return Michelson.pack(Michelson.some(a)); }
    function packNone() external pure returns (bytes memory) { return Michelson.pack(Michelson.none()); }
    function packList(bytes[] memory items) external pure returns (bytes memory) { return Michelson.pack(Michelson.list(items)); }
    function packMap(bytes[] memory elts) external pure returns (bytes memory) { return Michelson.pack(Michelson.map(elts)); }
    function packSet(bytes[] memory items) external pure returns (bytes memory) { return Michelson.pack(Michelson.set(items)); }

    function unpackPair(bytes memory p) external pure returns (bytes memory, bytes memory) { return Michelson.toPair(Michelson.unpack(p)); }
    function unpackOr(bytes memory p) external pure returns (bool, bytes memory) { return Michelson.toOr(Michelson.unpack(p)); }
    function unpackOption(bytes memory p) external pure returns (bool, bytes memory) { return Michelson.toOption(Michelson.unpack(p)); }
    function unpackList(bytes memory p) external pure returns (bytes[] memory) { return Michelson.toList(Michelson.unpack(p)); }
    function unpackMap(bytes memory p) external pure returns (bytes[] memory) { return Michelson.toMap(Michelson.unpack(p)); }
    function unpackSet(bytes memory p) external pure returns (bytes[] memory) { return Michelson.toSet(Michelson.unpack(p)); }
}

// ================================================================
// NAT
// ================================================================

contract MichelsonAsmNatTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

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
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackNat(hex"");
    }

    function test_unpackNat_too_short_reverts() public {
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackNat(hex"0500");
    }

    function test_unpackNat_wrong_version_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackNat(hex"060001");
    }

    function test_unpackNat_wrong_tag_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.UnexpectedNodeTag.selector, uint8(0x00), uint8(0x01)));
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
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackNat(hex"050080");
    }
}

// ================================================================
// INT
// ================================================================

contract MichelsonAsmIntTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    // Known vectors
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
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackInt(hex"0500c0");
    }

    function test_unpackInt_empty_reverts() public {
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackInt(hex"");
    }
}

// ================================================================
// BOOL
// ================================================================

contract MichelsonAsmBoolTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

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
        vm.expectRevert(abi.encodeWithSelector(Michelson.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackBool(hex"06030a");
    }

    function test_unpackBool_wrong_tag() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.UnexpectedNodeTag.selector, uint8(0x03), uint8(0x00)));
        h.unpackBool(hex"05000a");
    }

    function test_unpackBool_invalid_prim() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidBoolTag.selector, uint8(0x0B)));
        h.unpackBool(hex"05030b");
    }

    function test_unpackBool_empty() public {
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackBool(hex"");
    }

    function test_unpackBool_too_long() public {
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackBool(hex"05030a00");
    }
}

// ================================================================
// UNIT
// ================================================================

contract MichelsonAsmUnitTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packUnit() public view { assertEq(h.packUnit(), hex"05030b"); }

    function test_unpackUnit() public view { h.unpackUnit(hex"05030b"); }

    function test_unpackUnit_wrong_version() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackUnit(hex"06030b");
    }

    function test_unpackUnit_wrong_tag() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.UnexpectedNodeTag.selector, uint8(0x03), uint8(0x00)));
        h.unpackUnit(hex"05000b");
    }

    function test_unpackUnit_wrong_prim() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.UnexpectedNodeTag.selector, uint8(0x0B), uint8(0x0A)));
        h.unpackUnit(hex"05030a");
    }

    function test_unpackUnit_empty() public {
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackUnit(hex"");
    }
}

// ================================================================
// STRING
// ================================================================

contract MichelsonAsmStringTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

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
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackString(hex"0501");
    }

    function test_unpackString_wrong_version() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackString(hex"060100000000");
    }

    function test_unpackString_wrong_tag() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.UnexpectedNodeTag.selector, uint8(0x01), uint8(0x00)));
        h.unpackString(hex"050000000000");
    }

    function test_unpackString_trailing_bytes() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.TrailingBytes.selector, uint256(5), uint256(6)));
        h.unpackString(hex"05010000000000");
    }

    function test_unpackString_length_too_large() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.TrailingBytes.selector, uint256(6), uint256(5)));
        h.unpackString(hex"050100000001");
    }
}

// ================================================================
// BYTES
// ================================================================

contract MichelsonAsmBytesTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packBytes_deadbeef() public view {
        assertEq(h.packBytes(hex"deadbeef"), hex"050a00000004deadbeef");
    }

    function test_packBytes_empty() public view {
        assertEq(h.packBytes(hex""), hex"050a00000000");
    }

    function test_unpackBytes_deadbeef() public view {
        assertEq(h.unpackBytes(hex"050a00000004deadbeef"), hex"deadbeef");
    }

    function test_unpackBytes_empty() public view {
        bytes memory result = h.unpackBytes(hex"050a00000000");
        assertEq(result.length, 0);
    }

    function testFuzz_roundtrip_bytes(bytes memory data) public view {
        assertEq(keccak256(h.unpackBytes(h.packBytes(data))), keccak256(data));
    }

    // Invalid inputs
    function test_unpackBytes_truncated() public {
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackBytes(hex"050a");
    }

    function test_unpackBytes_wrong_version() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackBytes(hex"060a00000000");
    }

    function test_unpackBytes_wrong_tag() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.UnexpectedNodeTag.selector, uint8(0x0A), uint8(0x01)));
        h.unpackBytes(hex"050100000000");
    }

    function test_unpackBytes_trailing() public {
        vm.expectRevert(abi.encodeWithSelector(Michelson.TrailingBytes.selector, uint256(5), uint256(6)));
        h.unpackBytes(hex"050a0000000000");
    }
}

// ================================================================
// MUTEZ
// ================================================================

contract MichelsonAsmMutezTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packMutez_0() public view { assertEq(h.packMutez(0), hex"050000"); }
    function test_packMutez_1() public view { assertEq(h.packMutez(1), hex"050001"); }
    function test_packMutez_42() public view { assertEq(h.packMutez(42), hex"05002a"); }
    function test_packMutez_1000000() public view {
        assertEq(h.unpackMutez(h.packMutez(1000000)), 1000000);
    }

    function test_unpackMutez_0() public view { assertEq(h.unpackMutez(hex"050000"), 0); }
    function test_unpackMutez_42() public view { assertEq(h.unpackMutez(hex"05002a"), 42); }

    function testFuzz_roundtrip_mutez(uint64 v) public view {
        vm.assume(v <= type(uint64).max / 2);
        assertEq(h.unpackMutez(h.packMutez(v)), v);
    }

    function test_packMutez_maxValid() public view {
        uint64 maxMutez = type(uint64).max / 2;
        assertEq(h.unpackMutez(h.packMutez(maxMutez)), maxMutez);
    }

    function test_unpackMutez_overflow_reverts() public {
        bytes memory packed = Michelson.pack(Michelson.nat(uint256(type(uint64).max / 2) + 1));
        vm.expectRevert(Michelson.IntOverflow.selector);
        h.unpackMutez(packed);
    }

    function test_unpackMutez_large_nat_reverts() public {
        bytes memory packed = Michelson.pack(Michelson.nat(type(uint256).max));
        vm.expectRevert(Michelson.IntOverflow.selector);
        h.unpackMutez(packed);
    }

    function test_unpackMutez_empty_reverts() public {
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackMutez(hex"");
    }
}

// ================================================================
// TIMESTAMP
// ================================================================

contract MichelsonAsmTimestampTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packTimestamp_0() public view { assertEq(h.packTimestamp(0), hex"050000"); }
    function test_packTimestamp_1() public view { assertEq(h.packTimestamp(1), hex"050001"); }
    function test_packTimestamp_neg1() public view { assertEq(h.packTimestamp(-1), hex"050041"); }
    function test_packTimestamp_1000000() public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(1000000)), 1000000);
    }
    function test_packTimestamp_neg1000000() public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(-1000000)), -1000000);
    }

    function test_unpackTimestamp_0() public view { assertEq(h.unpackTimestamp(hex"050000"), 0); }
    function test_unpackTimestamp_neg1() public view { assertEq(h.unpackTimestamp(hex"050041"), -1); }

    function testFuzz_roundtrip_timestamp(int64 v) public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(v)), v);
    }

    function test_packTimestamp_maxInt64() public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(type(int64).max)), type(int64).max);
    }

    function test_packTimestamp_minInt64() public view {
        assertEq(h.unpackTimestamp(h.packTimestamp(type(int64).min)), type(int64).min);
    }

    function test_unpackTimestamp_overflow_positive_reverts() public {
        bytes memory packed = Michelson.pack(Michelson.int_(int256(type(int64).max) + 1));
        vm.expectRevert(Michelson.IntOverflow.selector);
        h.unpackTimestamp(packed);
    }

    function test_unpackTimestamp_overflow_negative_reverts() public {
        bytes memory packed = Michelson.pack(Michelson.int_(int256(type(int64).min) - 1));
        vm.expectRevert(Michelson.IntOverflow.selector);
        h.unpackTimestamp(packed);
    }

    function test_unpackTimestamp_empty_reverts() public {
        vm.expectRevert(Michelson.InputTruncated.selector);
        h.unpackTimestamp(hex"");
    }
}

// ================================================================
// ADDRESS
// ================================================================

contract MichelsonAsmAddressTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packAddress_tz1() public view {
        bytes memory addr = hex"00006b82198cb179e8306c1bedd08f12dc863f328886";
        assertEq(h.packAddress(addr), hex"050a0000001600006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    function test_unpackAddress_tz1() public view {
        bytes memory addr = h.unpackAddress(hex"050a0000001600006b82198cb179e8306c1bedd08f12dc863f328886");
        assertEq(addr, hex"00006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    function test_packAddress_with_entrypoint() public view {
        bytes memory addrWithEp = hex"00006b82198cb179e8306c1bedd08f12dc863f3288867472616e73666572";
        assertEq(h.packAddress(addrWithEp), hex"050a0000001e00006b82198cb179e8306c1bedd08f12dc863f3288867472616e73666572");
    }

    function testFuzz_roundtrip_address(bytes memory addr) public view {
        assertEq(keccak256(h.unpackAddress(h.packAddress(addr))), keccak256(addr));
    }
}

// ================================================================
// KEY_HASH
// ================================================================

contract MichelsonAsmKeyHashTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packKeyHash_tz1() public view {
        bytes memory kh = hex"006b82198cb179e8306c1bedd08f12dc863f328886";
        assertEq(h.packKeyHash(kh), hex"050a00000015006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    function test_unpackKeyHash_tz1() public view {
        bytes memory kh = h.unpackKeyHash(hex"050a00000015006b82198cb179e8306c1bedd08f12dc863f328886");
        assertEq(kh, hex"006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    function testFuzz_roundtrip_keyhash(bytes memory kh) public view {
        assertEq(keccak256(h.unpackKeyHash(h.packKeyHash(kh))), keccak256(kh));
    }
}

// ================================================================
// KEY
// ================================================================

contract MichelsonAsmKeyTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packKey_ed25519() public view {
        bytes memory k = hex"00d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af";
        assertEq(h.packKey(k), hex"050a0000002100d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af");
    }

    function test_unpackKey_ed25519() public view {
        bytes memory k = h.unpackKey(hex"050a0000002100d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af");
        assertEq(k, hex"00d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af");
    }

    function testFuzz_roundtrip_key(bytes memory k) public view {
        assertEq(keccak256(h.unpackKey(h.packKey(k))), keccak256(k));
    }
}

// ================================================================
// SIGNATURE
// ================================================================

contract MichelsonAsmSignatureTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packSignature_64bytes() public view {
        bytes memory sig = new bytes(64);
        for (uint256 i = 0; i < 64; i++) sig[i] = bytes1(uint8(i));
        bytes memory packed = h.packSignature(sig);
        assertEq(packed.length, 70);
        assertEq(uint8(packed[0]), 0x05);
        assertEq(uint8(packed[1]), 0x0A);
        assertEq(uint8(packed[2]), 0x00);
        assertEq(uint8(packed[3]), 0x00);
        assertEq(uint8(packed[4]), 0x00);
        assertEq(uint8(packed[5]), 0x40);
    }

    function test_unpackSignature_roundtrip() public view {
        bytes memory sig = new bytes(64);
        for (uint256 i = 0; i < 64; i++) sig[i] = bytes1(uint8(i));
        assertEq(keccak256(h.unpackSignature(h.packSignature(sig))), keccak256(sig));
    }

    function testFuzz_roundtrip_signature(bytes memory sig) public view {
        assertEq(keccak256(h.unpackSignature(h.packSignature(sig))), keccak256(sig));
    }
}

// ================================================================
// CHAIN_ID
// ================================================================

contract MichelsonAsmChainIdTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packChainId_mainnet() public view {
        bytes memory cid = hex"7a06a770";
        assertEq(h.packChainId(cid), hex"050a000000047a06a770");
    }

    function test_unpackChainId_mainnet() public view {
        bytes memory cid = h.unpackChainId(hex"050a000000047a06a770");
        assertEq(cid, hex"7a06a770");
    }

    function testFuzz_roundtrip_chainid(bytes memory cid) public view {
        assertEq(keccak256(h.unpackChainId(h.packChainId(cid))), keccak256(cid));
    }
}

// ================================================================
// CONTRACT
// ================================================================

contract MichelsonAsmContractTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packContract_default() public view {
        bytes memory addr = hex"00006b82198cb179e8306c1bedd08f12dc863f328886";
        assertEq(h.packContract(addr), hex"050a0000001600006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    function test_packContract_with_entrypoint() public view {
        bytes memory data = hex"00006b82198cb179e8306c1bedd08f12dc863f3288867472616e73666572";
        assertEq(h.packContract(data), hex"050a0000001e00006b82198cb179e8306c1bedd08f12dc863f3288867472616e73666572");
    }

    function test_unpackContract_default() public view {
        bytes memory data = h.unpackContract(hex"050a0000001600006b82198cb179e8306c1bedd08f12dc863f328886");
        assertEq(data, hex"00006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    function testFuzz_roundtrip_contract(bytes memory data) public view {
        assertEq(keccak256(h.unpackContract(h.packContract(data))), keccak256(data));
    }
}

// ================================================================
// PAIR
// ================================================================

contract MichelsonAsmPairTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    // Known vector: Pair 42 "hello" -> 0x050707002a010000000568656c6c6f
    function test_packPair_nat_string() public view {
        bytes memory encA = h.nat(42);
        bytes memory encB = h.string_("hello");
        assertEq(h.packPair(encA, encB), hex"050707002a010000000568656c6c6f");
    }

    function test_unpackPair_nat_string() public view {
        (bytes memory a, bytes memory b) = h.unpackPair(hex"050707002a010000000568656c6c6f");
        assertEq(a, hex"002a");
        assertEq(b, hex"010000000568656c6c6f");
    }

    function testFuzz_pair_roundtrip(uint256 n, int256 v) public view {
        bytes memory encA = h.nat(n);
        bytes memory encB = h.int_(v);
        bytes memory packed = h.packPair(encA, encB);
        (bytes memory decA, bytes memory decB) = h.unpackPair(packed);
        assertEq(keccak256(decA), keccak256(encA));
        assertEq(keccak256(decB), keccak256(encB));
    }

    function test_nested_pair() public view {
        bytes memory inner = h.pair(h.nat(2), h.nat(3));
        bytes memory packed = h.packPair(h.nat(1), inner);
        (bytes memory a, bytes memory b) = h.unpackPair(packed);
        assertEq(a, h.nat(1));
        assertEq(keccak256(b), keccak256(inner));
    }
}

// ================================================================
// OR
// ================================================================

contract MichelsonAsmOrTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packLeft_nat() public view {
        assertEq(h.packLeft(h.nat(42)), hex"050505002a");
    }
    function test_packRight_string() public view {
        assertEq(h.packRight(h.string_("hello")), hex"050508010000000568656c6c6f");
    }

    function test_unpackOr_left() public view {
        (bool isLeft, bytes memory val) = h.unpackOr(hex"050505002a");
        assertTrue(isLeft);
        assertEq(val, hex"002a");
    }
    function test_unpackOr_right() public view {
        (bool isLeft, bytes memory val) = h.unpackOr(hex"050508010000000568656c6c6f");
        assertFalse(isLeft);
        assertEq(val, hex"010000000568656c6c6f");
    }

    function testFuzz_or_left_roundtrip(uint256 n) public view {
        bytes memory enc = h.nat(n);
        (bool isLeft, bytes memory val) = h.unpackOr(h.packLeft(enc));
        assertTrue(isLeft);
        assertEq(keccak256(val), keccak256(enc));
    }
    function testFuzz_or_right_roundtrip(int256 v) public view {
        bytes memory enc = h.int_(v);
        (bool isLeft, bytes memory val) = h.unpackOr(h.packRight(enc));
        assertFalse(isLeft);
        assertEq(keccak256(val), keccak256(enc));
    }
}

// ================================================================
// OPTION
// ================================================================

contract MichelsonAsmOptionTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packSome_nat() public view {
        assertEq(h.packSome(h.nat(42)), hex"050509002a");
    }
    function test_packNone() public view {
        assertEq(h.packNone(), hex"050306");
    }

    function test_unpackOption_some() public view {
        (bool isSome, bytes memory val) = h.unpackOption(hex"050509002a");
        assertTrue(isSome);
        assertEq(val, hex"002a");
    }
    function test_unpackOption_none() public view {
        (bool isSome, bytes memory val) = h.unpackOption(hex"050306");
        assertFalse(isSome);
        assertEq(val.length, 0);
    }

    function testFuzz_option_some_roundtrip(uint256 n) public view {
        bytes memory enc = h.nat(n);
        (bool isSome, bytes memory val) = h.unpackOption(h.packSome(enc));
        assertTrue(isSome);
        assertEq(keccak256(val), keccak256(enc));
    }
    function test_option_none_roundtrip() public view {
        (bool isSome,) = h.unpackOption(h.packNone());
        assertFalse(isSome);
    }
}

// ================================================================
// LIST
// ================================================================

contract MichelsonAsmListTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packList_123() public view {
        bytes[] memory items = new bytes[](3);
        items[0] = h.nat(1);
        items[1] = h.nat(2);
        items[2] = h.nat(3);
        assertEq(h.packList(items), hex"050200000006000100020003");
    }

    function test_packList_empty() public view {
        bytes[] memory items = new bytes[](0);
        assertEq(h.packList(items), hex"050200000000");
    }

    function test_unpackList_123() public view {
        bytes[] memory items = h.unpackList(hex"050200000006000100020003");
        assertEq(items.length, 3);
        assertEq(items[0], hex"0001");
        assertEq(items[1], hex"0002");
        assertEq(items[2], hex"0003");
    }

    function test_unpackList_empty() public view {
        bytes[] memory items = h.unpackList(hex"050200000000");
        assertEq(items.length, 0);
    }

    function test_list_roundtrip() public view {
        bytes[] memory items = new bytes[](3);
        items[0] = h.nat(100);
        items[1] = h.nat(200);
        items[2] = h.nat(300);
        bytes memory packed = h.packList(items);
        bytes[] memory decoded = h.unpackList(packed);
        assertEq(decoded.length, items.length);
        for (uint i = 0; i < items.length; i++) {
            assertEq(keccak256(decoded[i]), keccak256(items[i]));
        }
    }
}

// ================================================================
// MAP
// ================================================================

contract MichelsonAsmMapTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packMap_elt_1_a_2_b() public view {
        bytes memory elt1 = h.elt(h.nat(1), h.string_("a"));
        bytes memory elt2 = h.elt(h.nat(2), h.string_("b"));
        bytes[] memory elts = new bytes[](2);
        elts[0] = elt1;
        elts[1] = elt2;
        assertEq(h.packMap(elts), hex"0502000000140704000101000000016107040002010000000162");
    }

    function test_elt() public view {
        bytes memory e = h.elt(h.nat(1), h.string_("a"));
        assertEq(e, hex"07040001010000000161");
    }

    function test_packMap_empty() public view {
        bytes[] memory elts = new bytes[](0);
        assertEq(h.packMap(elts), hex"050200000000");
    }

    function test_unpackMap() public view {
        bytes[] memory elts = h.unpackMap(hex"0502000000140704000101000000016107040002010000000162");
        assertEq(elts.length, 2);
        assertEq(elts[0], hex"07040001010000000161");
        assertEq(elts[1], hex"07040002010000000162");
    }

    function test_unpackMap_empty() public view {
        bytes[] memory elts = h.unpackMap(hex"050200000000");
        assertEq(elts.length, 0);
    }
}

// ================================================================
// SET
// ================================================================

contract MichelsonAsmSetTest is Test {
    AsmHarness h;
    function setUp() public { h = new AsmHarness(); }

    function test_packSet_123() public view {
        bytes[] memory items = new bytes[](3);
        items[0] = h.nat(1);
        items[1] = h.nat(2);
        items[2] = h.nat(3);
        assertEq(h.packSet(items), hex"050200000006000100020003");
    }

    function test_packSet_empty() public view {
        bytes[] memory items = new bytes[](0);
        assertEq(h.packSet(items), hex"050200000000");
    }

    function test_unpackSet() public view {
        bytes[] memory items = h.unpackSet(hex"050200000006000100020003");
        assertEq(items.length, 3);
        assertEq(items[0], hex"0001");
        assertEq(items[1], hex"0002");
        assertEq(items[2], hex"0003");
    }
}
