// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MichelsonSpec.sol";

/// @dev Harness exposing internal library functions for testing.
contract EVMConvertHarness {
    // Pack/unpack via new API
    function packNat(uint256 n) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.nat(n)); }
    function unpackNat(bytes memory p) external pure returns (uint256) { return MichelsonSpec.toNat(MichelsonSpec.unpack(p)); }
    function packInt(int256 v) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.int_(v)); }
    function unpackInt(bytes memory p) external pure returns (int256) { return MichelsonSpec.toInt(MichelsonSpec.unpack(p)); }
    function packBool(bool v) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bool_(v)); }
    function unpackBool(bytes memory p) external pure returns (bool) { return MichelsonSpec.toBool(MichelsonSpec.unpack(p)); }
    function packString(string memory s) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.string_(s)); }
    function unpackString(bytes memory p) external pure returns (string memory) { return MichelsonSpec.toString(MichelsonSpec.unpack(p)); }
}

// ================================================================
// NAT: roundtrip
// ================================================================

contract EVMConvertNatTest is Test {
    EVMConvertHarness h;
    function setUp() public { h = new EVMConvertHarness(); }

    /// @dev Roundtrip: unpackNat(packNat(n)) == n
    function testFuzz_nat_roundtrip(uint256 n) public view {
        assertEq(h.unpackNat(h.packNat(n)), n);
    }

    // Known vectors
    function test_nat_0() public view { assertEq(h.unpackNat(hex"050000"), 0); }
    function test_nat_1() public view { assertEq(h.unpackNat(hex"050001"), 1); }
    function test_nat_42() public view { assertEq(h.unpackNat(hex"05002a"), 42); }
    function test_nat_63() public view { assertEq(h.unpackNat(hex"05003f"), 63); }
    function test_nat_64() public view { assertEq(h.unpackNat(hex"05008001"), 64); }
    function test_nat_128() public view { assertEq(h.unpackNat(hex"05008002"), 128); }
    function test_nat_256() public view { assertEq(h.unpackNat(hex"05008004"), 256); }

    function test_nat_maxUint256() public view {
        assertEq(h.unpackNat(h.packNat(type(uint256).max)), type(uint256).max);
    }

    function test_nat_powers_of_two() public view {
        for (uint256 i = 0; i < 256; i++) {
            uint256 n = 1 << i;
            assertEq(h.unpackNat(h.packNat(n)), n);
        }
    }

    // Boundary values
    function test_nat_boundary_63() public view { assertEq(h.unpackNat(h.packNat(63)), 63); }
    function test_nat_boundary_64() public view { assertEq(h.unpackNat(h.packNat(64)), 64); }
    function test_nat_boundary_127() public view { assertEq(h.unpackNat(h.packNat(127)), 127); }
    function test_nat_boundary_128() public view { assertEq(h.unpackNat(h.packNat(128)), 128); }
    function test_nat_boundary_255() public view { assertEq(h.unpackNat(h.packNat(255)), 255); }
    function test_nat_boundary_256() public view { assertEq(h.unpackNat(h.packNat(256)), 256); }
    function test_nat_boundary_8191() public view { assertEq(h.unpackNat(h.packNat(8191)), 8191); }
    function test_nat_boundary_8192() public view { assertEq(h.unpackNat(h.packNat(8192)), 8192); }

    // Error cases
    function test_nat_empty_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackNat(hex"");
    }

    function test_nat_wrong_version_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackNat(hex"060001");
    }

    function test_nat_wrong_tag_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x00), uint8(0x01)));
        h.unpackNat(hex"050101");
    }
}

// ================================================================
// INT: roundtrip
// ================================================================

contract EVMConvertIntTest is Test {
    EVMConvertHarness h;
    function setUp() public { h = new EVMConvertHarness(); }

    /// @dev Roundtrip: unpackInt(packInt(v)) == v
    function testFuzz_int_roundtrip(int256 v) public view {
        assertEq(h.unpackInt(h.packInt(v)), v);
    }

    // Known vectors
    function test_int_0() public view { assertEq(h.unpackInt(hex"050000"), int256(0)); }
    function test_int_1() public view { assertEq(h.unpackInt(hex"050001"), int256(1)); }
    function test_int_neg1() public view { assertEq(h.unpackInt(hex"050041"), int256(-1)); }
    function test_int_42() public view { assertEq(h.unpackInt(hex"05002a"), int256(42)); }
    function test_int_neg64() public view { assertEq(h.unpackInt(hex"0500c001"), int256(-64)); }

    function test_int_maxInt256() public view {
        assertEq(h.unpackInt(h.packInt(type(int256).max)), type(int256).max);
    }

    function test_int_minInt256() public view {
        assertEq(h.unpackInt(h.packInt(type(int256).min)), type(int256).min);
    }
}

// ================================================================
// BOOL: roundtrip
// ================================================================

contract EVMConvertBoolTest is Test {
    EVMConvertHarness h;
    function setUp() public { h = new EVMConvertHarness(); }

    function testFuzz_bool_roundtrip(bool v) public view {
        assertEq(h.unpackBool(h.packBool(v)), v);
    }

    function test_bool_true() public view {
        assertTrue(h.unpackBool(hex"05030a"));
    }

    function test_bool_false() public view {
        assertFalse(h.unpackBool(hex"050303"));
    }
}

// ================================================================
// STRING: roundtrip
// ================================================================

contract EVMConvertStringTest is Test {
    EVMConvertHarness h;
    function setUp() public { h = new EVMConvertHarness(); }

    function testFuzz_string_roundtrip(string memory s) public view {
        assertEq(h.unpackString(h.packString(s)), s);
    }

    function test_string_empty() public view {
        assertEq(h.unpackString(h.packString("")), "");
    }

    function test_string_hello() public view {
        assertEq(h.unpackString(h.packString("hello")), "hello");
    }

    function test_string_long() public view {
        bytes memory b = new bytes(256);
        for (uint256 i = 0; i < 256; i++) {
            b[i] = bytes1(uint8(65 + (i % 26)));
        }
        string memory s = string(b);
        assertEq(h.unpackString(h.packString(s)), s);
    }

    function test_string_tezos_address() public view {
        string memory addr = "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb";
        assertEq(h.unpackString(h.packString(addr)), addr);
    }
}
