// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MichelsonSpec.sol";
import "../src/Michelson.sol";

/// @dev Harness that exposes both spec and asm implementations for comparison.
contract AsmDiffHarness {
    // Spec (verified, from Lean) -- uses new API: pack(nat(n)), toNat(unpack(p))
    function specUnpackNat(bytes memory p) external pure returns (uint256) {
        return MichelsonSpec.toNat(MichelsonSpec.unpack(p));
    }
    function specUnpackInt(bytes memory p) external pure returns (int256) {
        return MichelsonSpec.toInt(MichelsonSpec.unpack(p));
    }
    function specPackNat(uint256 n) external pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.nat(n));
    }
    function specPackInt(int256 v) external pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.int_(v));
    }
    function specPackBool(bool v) external pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.bool_(v));
    }
    function specUnpackBool(bytes memory p) external pure returns (bool) {
        return MichelsonSpec.toBool(MichelsonSpec.unpack(p));
    }
    function specPackUnit() external pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.unit_());
    }
    function specUnpackUnit(bytes memory p) external pure {
        MichelsonSpec.toUnit(MichelsonSpec.unpack(p));
    }
    function specPackString(string memory s) external pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.string_(s));
    }
    function specUnpackString(bytes memory p) external pure returns (string memory) {
        return MichelsonSpec.toString(MichelsonSpec.unpack(p));
    }
    function specPackMutez(uint64 v) external pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.nat(uint256(v)));
    }
    function specUnpackMutez(bytes memory p) external pure returns (uint64) {
        return MichelsonSpec.toMutez(MichelsonSpec.unpack(p));
    }
    function specPackTimestamp(int64 v) external pure returns (bytes memory) {
        return MichelsonSpec.pack(MichelsonSpec.int_(int256(v)));
    }
    function specUnpackTimestamp(bytes memory p) external pure returns (int64) {
        return MichelsonSpec.toTimestamp(MichelsonSpec.unpack(p));
    }

    // Assembly (optimized)
    function asmUnpackNat(bytes memory p) external pure returns (uint256) {
        return Michelson.toNat(Michelson.unpack(p));
    }
    function asmUnpackInt(bytes memory p) external pure returns (int256) {
        return Michelson.toInt(Michelson.unpack(p));
    }
    function asmPackToEVMNat(bytes memory p) external pure returns (bytes32) {
        return Michelson.packToEVMNat(p);
    }
    function asmPackToEVMInt(bytes memory p) external pure returns (bytes32) {
        return Michelson.packToEVMInt(p);
    }
    function asmPackNat(uint256 n) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.nat(n));
    }
    function asmPackInt(int256 v) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.int_(v));
    }
    function asmPackBool(bool v) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.bool_(v));
    }
    function asmUnpackBool(bytes memory p) external pure returns (bool) {
        return Michelson.toBool(Michelson.unpack(p));
    }
    function asmPackUnit() external pure returns (bytes memory) {
        return Michelson.pack(Michelson.unit_());
    }
    function asmUnpackUnit(bytes memory p) external pure {
        Michelson.toUnit(Michelson.unpack(p));
    }
    function asmPackString(string memory s) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.string_(s));
    }
    function asmUnpackString(bytes memory p) external pure returns (string memory) {
        return Michelson.toString(Michelson.unpack(p));
    }
    function asmPackMutez(uint64 v) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.nat(uint256(v)));
    }
    function asmUnpackMutez(bytes memory p) external pure returns (uint64) {
        return Michelson.toMutez(Michelson.unpack(p));
    }
    function asmPackTimestamp(int64 v) external pure returns (bytes memory) {
        return Michelson.pack(Michelson.int_(int256(v)));
    }
    function asmUnpackTimestamp(bytes memory p) external pure returns (int64) {
        return Michelson.toTimestamp(Michelson.unpack(p));
    }

    // Bytes-node types: spec
    function specPackBytes(bytes memory data) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bytes_(data)); }
    function specUnpackBytes(bytes memory p) external pure returns (bytes memory) { return MichelsonSpec.toBytes(MichelsonSpec.unpack(p)); }
    function specPackAddress(bytes memory addr) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.address_(addr)); }
    function specUnpackAddress(bytes memory p) external pure returns (bytes memory) { return MichelsonSpec.toAddress(MichelsonSpec.unpack(p)); }
    function specPackKeyHash(bytes memory kh) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.keyHash(kh)); }
    function specUnpackKeyHash(bytes memory p) external pure returns (bytes memory) { return MichelsonSpec.toKeyHash(MichelsonSpec.unpack(p)); }
    function specPackKey(bytes memory k) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.key(k)); }
    function specUnpackKey(bytes memory p) external pure returns (bytes memory) { return MichelsonSpec.toKey(MichelsonSpec.unpack(p)); }
    function specPackSignature(bytes memory sig) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.signature_(sig)); }
    function specUnpackSignature(bytes memory p) external pure returns (bytes memory) { return MichelsonSpec.toSignature(MichelsonSpec.unpack(p)); }
    function specPackChainId(bytes memory cid) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bytes_(cid)); }
    function specUnpackChainId(bytes memory p) external pure returns (bytes memory) { return MichelsonSpec.toBytes(MichelsonSpec.unpack(p)); }
    function specPackContract(bytes memory data) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bytes_(data)); }
    function specUnpackContract(bytes memory p) external pure returns (bytes memory) { return MichelsonSpec.toBytes(MichelsonSpec.unpack(p)); }

    // Bytes-node types: asm
    function asmPackBytes(bytes memory data) external pure returns (bytes memory) { return Michelson.pack(Michelson.bytes_(data)); }
    function asmUnpackBytes(bytes memory p) external pure returns (bytes memory) { return Michelson.toBytes(Michelson.unpack(p)); }
    function asmPackAddress(bytes memory addr) external pure returns (bytes memory) { return Michelson.pack(Michelson.address_(addr)); }
    function asmUnpackAddress(bytes memory p) external pure returns (bytes memory) { return Michelson.toAddress(Michelson.unpack(p)); }
    function asmPackKeyHash(bytes memory kh) external pure returns (bytes memory) { return Michelson.pack(Michelson.keyHash(kh)); }
    function asmUnpackKeyHash(bytes memory p) external pure returns (bytes memory) { return Michelson.toKeyHash(Michelson.unpack(p)); }
    function asmPackKey(bytes memory k) external pure returns (bytes memory) { return Michelson.pack(Michelson.key(k)); }
    function asmUnpackKey(bytes memory p) external pure returns (bytes memory) { return Michelson.toKey(Michelson.unpack(p)); }
    function asmPackSignature(bytes memory sig) external pure returns (bytes memory) { return Michelson.pack(Michelson.signature_(sig)); }
    function asmUnpackSignature(bytes memory p) external pure returns (bytes memory) { return Michelson.toSignature(Michelson.unpack(p)); }
    function asmPackChainId(bytes memory cid) external pure returns (bytes memory) { return Michelson.pack(Michelson.chainId(cid)); }
    function asmUnpackChainId(bytes memory p) external pure returns (bytes memory) { return Michelson.toChainId(Michelson.unpack(p)); }
    function asmPackContract(bytes memory data) external pure returns (bytes memory) { return Michelson.pack(Michelson.contract_(data)); }
    function asmUnpackContract(bytes memory p) external pure returns (bytes memory) { return Michelson.toContract(Michelson.unpack(p)); }

    // Map/Set: spec
    function specElt(bytes memory k, bytes memory v) external pure returns (bytes memory) { return MichelsonSpec.elt(k, v); }
    function specPackMap(bytes[] memory elts) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.map(elts)); }
    function specUnpackMap(bytes memory p) external pure returns (bytes[] memory) { return MichelsonSpec.toMap(MichelsonSpec.unpack(p)); }
    function specPackSet(bytes[] memory items) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.set(items)); }
    function specUnpackSet(bytes memory p) external pure returns (bytes[] memory) { return MichelsonSpec.toSet(MichelsonSpec.unpack(p)); }

    // Map/Set: asm
    function asmElt(bytes memory k, bytes memory v) external pure returns (bytes memory) { return Michelson.elt(k, v); }
    function asmPackMap(bytes[] memory elts) external pure returns (bytes memory) { return Michelson.pack(Michelson.map(elts)); }
    function asmUnpackMap(bytes memory p) external pure returns (bytes[] memory) { return Michelson.toMap(Michelson.unpack(p)); }
    function asmPackSet(bytes[] memory items) external pure returns (bytes memory) { return Michelson.pack(Michelson.set(items)); }
    function asmUnpackSet(bytes memory p) external pure returns (bytes[] memory) { return Michelson.toSet(Michelson.unpack(p)); }

    // Composite: spec
    function specPair(bytes memory a, bytes memory b) external pure returns (bytes memory) { return MichelsonSpec.pair(a, b); }
    function specLeft(bytes memory a) external pure returns (bytes memory) { return MichelsonSpec.left(a); }
    function specRight(bytes memory b) external pure returns (bytes memory) { return MichelsonSpec.right(b); }
    function specSome(bytes memory a) external pure returns (bytes memory) { return MichelsonSpec.some(a); }
    function specNone() external pure returns (bytes memory) { return MichelsonSpec.none(); }
    function specList(bytes[] memory items) external pure returns (bytes memory) { return MichelsonSpec.list(items); }
    function specPackPair(bytes memory a, bytes memory b) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.pair(a, b)); }
    function specPackLeft(bytes memory a) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.left(a)); }
    function specPackRight(bytes memory b) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.right(b)); }
    function specPackSome(bytes memory a) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.some(a)); }
    function specPackNone() external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.none()); }
    function specPackList(bytes[] memory items) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.list(items)); }
    function specUnpackPair(bytes memory p) external pure returns (bytes memory, bytes memory) { return MichelsonSpec.toPair(MichelsonSpec.unpack(p)); }
    function specUnpackOr(bytes memory p) external pure returns (bool, bytes memory) { return MichelsonSpec.toOr(MichelsonSpec.unpack(p)); }
    function specUnpackOption(bytes memory p) external pure returns (bool, bytes memory) { return MichelsonSpec.toOption(MichelsonSpec.unpack(p)); }
    function specUnpackList(bytes memory p) external pure returns (bytes[] memory) { return MichelsonSpec.toList(MichelsonSpec.unpack(p)); }

    // Composite: asm
    function asmPair(bytes memory a, bytes memory b) external pure returns (bytes memory) { return Michelson.pair(a, b); }
    function asmLeft(bytes memory a) external pure returns (bytes memory) { return Michelson.left(a); }
    function asmRight(bytes memory b) external pure returns (bytes memory) { return Michelson.right(b); }
    function asmSome(bytes memory a) external pure returns (bytes memory) { return Michelson.some(a); }
    function asmNone() external pure returns (bytes memory) { return Michelson.none(); }
    function asmList(bytes[] memory items) external pure returns (bytes memory) { return Michelson.list(items); }
    function asmPackPair(bytes memory a, bytes memory b) external pure returns (bytes memory) { return Michelson.pack(Michelson.pair(a, b)); }
    function asmPackLeft(bytes memory a) external pure returns (bytes memory) { return Michelson.pack(Michelson.left(a)); }
    function asmPackRight(bytes memory b) external pure returns (bytes memory) { return Michelson.pack(Michelson.right(b)); }
    function asmPackSome(bytes memory a) external pure returns (bytes memory) { return Michelson.pack(Michelson.some(a)); }
    function asmPackNone() external pure returns (bytes memory) { return Michelson.pack(Michelson.none()); }
    function asmPackList(bytes[] memory items) external pure returns (bytes memory) { return Michelson.pack(Michelson.list(items)); }
    function asmUnpackPair(bytes memory p) external pure returns (bytes memory, bytes memory) { return Michelson.toPair(Michelson.unpack(p)); }
    function asmUnpackOr(bytes memory p) external pure returns (bool, bytes memory) { return Michelson.toOr(Michelson.unpack(p)); }
    function asmUnpackOption(bytes memory p) external pure returns (bool, bytes memory) { return Michelson.toOption(Michelson.unpack(p)); }
    function asmUnpackList(bytes memory p) external pure returns (bytes[] memory) { return Michelson.toList(Michelson.unpack(p)); }
}

// ================================================================
// NAT: asm == spec for all valid inputs
// ================================================================

contract AsmDiffNatTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_unpackNat_asm_eq_spec(uint256 n) public view {
        bytes memory packed = h.specPackNat(n);
        uint256 fromSpec = h.specUnpackNat(packed);
        uint256 fromAsm = h.asmUnpackNat(packed);
        assertEq(fromAsm, fromSpec, "asm != spec");
    }

    function testFuzz_packToEVMNat_asm_roundtrip(uint256 n) public view {
        bytes memory packed = h.specPackNat(n);
        assertEq(uint256(h.asmPackToEVMNat(packed)), n);
    }

    function test_asm_nat_0() public view { assertEq(h.asmUnpackNat(hex"050000"), 0); }
    function test_asm_nat_1() public view { assertEq(h.asmUnpackNat(hex"050001"), 1); }
    function test_asm_nat_42() public view { assertEq(h.asmUnpackNat(hex"05002a"), 42); }
    function test_asm_nat_63() public view { assertEq(h.asmUnpackNat(hex"05003f"), 63); }
    function test_asm_nat_64() public view { assertEq(h.asmUnpackNat(hex"05008001"), 64); }
    function test_asm_nat_127() public view { assertEq(h.asmUnpackNat(hex"0500bf01"), 127); }
    function test_asm_nat_128() public view { assertEq(h.asmUnpackNat(hex"05008002"), 128); }
    function test_asm_nat_256() public view { assertEq(h.asmUnpackNat(hex"05008004"), 256); }

    function test_asm_nat_maxUint256() public view {
        bytes memory packed = h.specPackNat(type(uint256).max);
        assertEq(h.asmUnpackNat(packed), type(uint256).max);
    }

    function test_asm_nat_powers_of_two() public view {
        for (uint256 i = 0; i < 256; i++) {
            uint256 n = 1 << i;
            bytes memory packed = h.specPackNat(n);
            assertEq(h.asmUnpackNat(packed), n);
        }
    }

    function test_asm_nat_empty_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.asmUnpackNat(hex"");
    }

    function test_asm_nat_wrong_version_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.asmUnpackNat(hex"060001");
    }

    function test_asm_nat_negative_reverts() public {
        vm.expectRevert(MichelsonSpec.NatNegative.selector);
        h.asmUnpackNat(hex"050041");
    }

    function test_asm_nat_trailing_zero_reverts() public {
        vm.expectRevert(MichelsonSpec.TrailingZeroByte.selector);
        h.asmUnpackNat(hex"05008000");
    }

    function test_asm_nat_truncated_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.asmUnpackNat(hex"050080");
    }

    function testFuzz_packNat_asm_eq_spec(uint256 n) public view {
        bytes memory fromSpec = h.specPackNat(n);
        bytes memory fromAsm = h.asmPackNat(n);
        assertEq(keccak256(fromAsm), keccak256(fromSpec), "packNat asm != spec");
    }

    function testFuzz_packNat_asm_roundtrip(uint256 n) public view {
        bytes memory packed = h.asmPackNat(n);
        assertEq(h.specUnpackNat(packed), n, "packNat asm roundtrip failed");
    }

    function test_asm_packNat_0() public view {
        assertEq(keccak256(h.asmPackNat(0)), keccak256(hex"050000"));
    }
    function test_asm_packNat_42() public view {
        assertEq(keccak256(h.asmPackNat(42)), keccak256(hex"05002a"));
    }
    function test_asm_packNat_64() public view {
        assertEq(keccak256(h.asmPackNat(64)), keccak256(hex"05008001"));
    }
    function test_asm_packNat_128() public view {
        assertEq(keccak256(h.asmPackNat(128)), keccak256(hex"05008002"));
    }

    function test_gas_spec_nat() public {
        bytes memory packed = h.specPackNat(type(uint256).max);
        uint256 gasBefore = gasleft();
        h.specUnpackNat(packed);
        uint256 gasSpec = gasBefore - gasleft();

        gasBefore = gasleft();
        h.asmUnpackNat(packed);
        uint256 gasAsm = gasBefore - gasleft();

        emit log_named_uint("spec gas (uint256.max)", gasSpec);
        emit log_named_uint("asm gas  (uint256.max)", gasAsm);
        emit log_named_uint("savings", gasSpec > gasAsm ? gasSpec - gasAsm : 0);
    }
}

// ================================================================
// INT: asm == spec for all valid inputs
// ================================================================

contract AsmDiffIntTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_unpackInt_asm_eq_spec(int256 v) public view {
        bytes memory packed = h.specPackInt(v);
        int256 fromSpec = h.specUnpackInt(packed);
        int256 fromAsm = h.asmUnpackInt(packed);
        assertEq(fromAsm, fromSpec, "asm != spec");
    }

    function testFuzz_packToEVMInt_asm_roundtrip(int256 v) public view {
        bytes memory packed = h.specPackInt(v);
        assertEq(int256(uint256(h.asmPackToEVMInt(packed))), v);
    }

    function test_asm_int_0() public view { assertEq(h.asmUnpackInt(hex"050000"), int256(0)); }
    function test_asm_int_1() public view { assertEq(h.asmUnpackInt(hex"050001"), int256(1)); }
    function test_asm_int_neg1() public view { assertEq(h.asmUnpackInt(hex"050041"), int256(-1)); }
    function test_asm_int_42() public view { assertEq(h.asmUnpackInt(hex"05002a"), int256(42)); }
    function test_asm_int_neg42() public view { assertEq(h.asmUnpackInt(hex"05006a"), int256(-42)); }
    function test_asm_int_64() public view { assertEq(h.asmUnpackInt(hex"05008001"), int256(64)); }
    function test_asm_int_neg64() public view { assertEq(h.asmUnpackInt(hex"0500c001"), int256(-64)); }

    function test_asm_int_maxInt256() public view {
        bytes memory packed = h.specPackInt(type(int256).max);
        assertEq(h.asmUnpackInt(packed), type(int256).max);
    }

    function test_asm_int_minInt256() public view {
        bytes memory packed = h.specPackInt(type(int256).min);
        assertEq(h.asmUnpackInt(packed), type(int256).min);
    }

    function test_asm_int_negative_zero_reverts() public {
        vm.expectRevert(MichelsonSpec.NegativeZero.selector);
        h.asmUnpackInt(hex"050040");
    }

    function test_asm_int_trailing_zero_reverts() public {
        vm.expectRevert(MichelsonSpec.TrailingZeroByte.selector);
        h.asmUnpackInt(hex"0500c000");
    }

    function testFuzz_packInt_asm_eq_spec(int256 v) public view {
        bytes memory fromSpec = h.specPackInt(v);
        bytes memory fromAsm = h.asmPackInt(v);
        assertEq(keccak256(fromAsm), keccak256(fromSpec), "packInt asm != spec");
    }

    function testFuzz_packInt_asm_roundtrip(int256 v) public view {
        bytes memory packed = h.asmPackInt(v);
        assertEq(h.specUnpackInt(packed), v, "packInt asm roundtrip failed");
    }

    function test_asm_packInt_0() public view {
        assertEq(keccak256(h.asmPackInt(0)), keccak256(hex"050000"));
    }
    function test_asm_packInt_neg1() public view {
        assertEq(keccak256(h.asmPackInt(-1)), keccak256(hex"050041"));
    }
    function test_asm_packInt_64() public view {
        assertEq(keccak256(h.asmPackInt(64)), keccak256(hex"05008001"));
    }
    function test_asm_packInt_neg64() public view {
        assertEq(keccak256(h.asmPackInt(-64)), keccak256(hex"0500c001"));
    }
    function test_asm_packInt_maxInt256() public view {
        assertEq(keccak256(h.asmPackInt(type(int256).max)), keccak256(h.specPackInt(type(int256).max)));
    }
    function test_asm_packInt_minInt256() public view {
        assertEq(keccak256(h.asmPackInt(type(int256).min)), keccak256(h.specPackInt(type(int256).min)));
    }

    function test_gas_spec_int() public {
        bytes memory packed = h.specPackInt(type(int256).min);
        uint256 gasBefore = gasleft();
        h.specUnpackInt(packed);
        uint256 gasSpec = gasBefore - gasleft();

        gasBefore = gasleft();
        h.asmUnpackInt(packed);
        uint256 gasAsm = gasBefore - gasleft();

        emit log_named_uint("spec gas (int256.min)", gasSpec);
        emit log_named_uint("asm gas  (int256.min)", gasAsm);
        emit log_named_uint("savings", gasSpec > gasAsm ? gasSpec - gasAsm : 0);
    }
}

// ================================================================
// BOOL: asm == spec
// ================================================================

contract AsmDiffBoolTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_packBool_asm_eq_spec(bool v) public view {
        assertEq(keccak256(h.asmPackBool(v)), keccak256(h.specPackBool(v)), "packBool asm != spec");
    }

    function testFuzz_unpackBool_asm_eq_spec(bool v) public view {
        bytes memory packed = h.specPackBool(v);
        assertEq(h.asmUnpackBool(packed), h.specUnpackBool(packed), "unpackBool asm != spec");
    }

    function test_asm_packBool_true() public view { assertEq(keccak256(h.asmPackBool(true)), keccak256(hex"05030a")); }
    function test_asm_packBool_false() public view { assertEq(keccak256(h.asmPackBool(false)), keccak256(hex"050303")); }
    function test_asm_unpackBool_true() public view { assertTrue(h.asmUnpackBool(hex"05030a")); }
    function test_asm_unpackBool_false() public view { assertFalse(h.asmUnpackBool(hex"050303")); }

    function test_asm_unpackBool_wrong_length_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.asmUnpackBool(hex"0503");
    }
    function test_asm_unpackBool_wrong_version_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.asmUnpackBool(hex"06030a");
    }
    function test_asm_unpackBool_wrong_tag_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x03), uint8(0x00)));
        h.asmUnpackBool(hex"05000a");
    }
    function test_asm_unpackBool_invalid_bool_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidBoolTag.selector, uint8(0xFF)));
        h.asmUnpackBool(hex"0503ff");
    }
}

// ================================================================
// UNIT: asm == spec
// ================================================================

contract AsmDiffUnitTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function test_packUnit_asm_eq_spec() public view {
        assertEq(keccak256(h.asmPackUnit()), keccak256(h.specPackUnit()), "packUnit asm != spec");
    }

    function test_unpackUnit_asm_eq_spec() public view {
        bytes memory packed = h.specPackUnit();
        h.specUnpackUnit(packed);
        h.asmUnpackUnit(packed);
    }

    function test_asm_packUnit() public view { assertEq(keccak256(h.asmPackUnit()), keccak256(hex"05030b")); }

    function test_asm_unpackUnit_wrong_length_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.asmUnpackUnit(hex"0503");
    }
    function test_asm_unpackUnit_wrong_version_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.asmUnpackUnit(hex"06030b");
    }
    function test_asm_unpackUnit_wrong_tag1_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x03), uint8(0x00)));
        h.asmUnpackUnit(hex"05000b");
    }
    function test_asm_unpackUnit_wrong_tag2_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x0B), uint8(0x0A)));
        h.asmUnpackUnit(hex"05030a");
    }
}

// ================================================================
// STRING: asm == spec
// ================================================================

contract AsmDiffStringTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_packString_asm_eq_spec(string memory s) public view {
        if (bytes(s).length > 1024) return;
        assertEq(keccak256(h.asmPackString(s)), keccak256(h.specPackString(s)), "packString asm != spec");
    }

    function testFuzz_unpackString_asm_eq_spec(string memory s) public view {
        if (bytes(s).length > 1024) return;
        bytes memory packed = h.specPackString(s);
        assertEq(keccak256(bytes(h.asmUnpackString(packed))), keccak256(bytes(h.specUnpackString(packed))), "unpackString asm != spec");
    }

    function test_asm_packString_empty() public view { assertEq(keccak256(h.asmPackString("")), keccak256(hex"050100000000")); }
    function test_asm_packString_hello() public view { assertEq(keccak256(h.asmPackString("hello")), keccak256(h.specPackString("hello"))); }
    function test_asm_unpackString_hello() public view {
        bytes memory packed = h.specPackString("hello");
        assertEq(keccak256(bytes(h.asmUnpackString(packed))), keccak256(bytes("hello")));
    }

    function test_asm_string_roundtrip() public view {
        string memory s = "The quick brown fox jumps over the lazy dog";
        assertEq(keccak256(bytes(h.asmUnpackString(h.asmPackString(s)))), keccak256(bytes(s)));
    }

    function test_asm_unpackString_truncated_reverts() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.asmUnpackString(hex"0501");
    }
    function test_asm_unpackString_wrong_version_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.asmUnpackString(hex"060100000000");
    }
    function test_asm_unpackString_wrong_tag_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x01), uint8(0x00)));
        h.asmUnpackString(hex"050000000000");
    }
}

// ================================================================
// MUTEZ: asm == spec
// ================================================================

contract AsmDiffMutezTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_packMutez_asm_eq_spec(uint64 v) public view {
        vm.assume(v <= type(uint64).max / 2);
        assertEq(keccak256(h.asmPackMutez(v)), keccak256(h.specPackMutez(v)), "packMutez asm != spec");
    }

    function testFuzz_unpackMutez_asm_eq_spec(uint64 v) public view {
        vm.assume(v <= type(uint64).max / 2);
        bytes memory packed = h.specPackMutez(v);
        assertEq(h.asmUnpackMutez(packed), h.specUnpackMutez(packed), "unpackMutez asm != spec");
    }

    function test_asm_packMutez_0() public view { assertEq(keccak256(h.asmPackMutez(0)), keccak256(h.specPackMutez(0))); }
    function test_asm_packMutez_1M() public view { assertEq(keccak256(h.asmPackMutez(1000000)), keccak256(h.specPackMutez(1000000))); }
    function test_asm_unpackMutez_1M() public view {
        bytes memory packed = h.specPackMutez(1000000);
        assertEq(h.asmUnpackMutez(packed), 1000000);
    }

    function test_asm_unpackMutez_overflow_reverts() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.nat(uint256(type(uint64).max)));
        vm.expectRevert(MichelsonSpec.IntOverflow.selector);
        h.asmUnpackMutez(packed);
    }
}

// ================================================================
// TIMESTAMP: asm == spec
// ================================================================

contract AsmDiffTimestampTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_packTimestamp_asm_eq_spec(int64 v) public view {
        assertEq(keccak256(h.asmPackTimestamp(v)), keccak256(h.specPackTimestamp(v)), "packTimestamp asm != spec");
    }

    function testFuzz_unpackTimestamp_asm_eq_spec(int64 v) public view {
        bytes memory packed = h.specPackTimestamp(v);
        assertEq(h.asmUnpackTimestamp(packed), h.specUnpackTimestamp(packed), "unpackTimestamp asm != spec");
    }

    function test_asm_packTimestamp_0() public view { assertEq(keccak256(h.asmPackTimestamp(0)), keccak256(h.specPackTimestamp(0))); }
    function test_asm_packTimestamp_neg1M() public view { assertEq(keccak256(h.asmPackTimestamp(-1000000)), keccak256(h.specPackTimestamp(-1000000))); }
    function test_asm_unpackTimestamp_neg1M() public view {
        bytes memory packed = h.specPackTimestamp(-1000000);
        assertEq(h.asmUnpackTimestamp(packed), int64(-1000000));
    }
    function test_asm_packTimestamp_max() public view { assertEq(keccak256(h.asmPackTimestamp(type(int64).max)), keccak256(h.specPackTimestamp(type(int64).max))); }
    function test_asm_packTimestamp_min() public view { assertEq(keccak256(h.asmPackTimestamp(type(int64).min)), keccak256(h.specPackTimestamp(type(int64).min))); }

    function test_asm_unpackTimestamp_overflow_reverts() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.int_(int256(type(int64).max) + 1));
        vm.expectRevert(MichelsonSpec.IntOverflow.selector);
        h.asmUnpackTimestamp(packed);
    }
    function test_asm_unpackTimestamp_underflow_reverts() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.int_(int256(type(int64).min) - 1));
        vm.expectRevert(MichelsonSpec.IntOverflow.selector);
        h.asmUnpackTimestamp(packed);
    }
}

// ================================================================
// PAIR: asm == spec
// ================================================================

contract AsmDiffPairTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_pair_asm_eq_spec(uint256 a, int256 b) public view {
        bytes memory encA = MichelsonSpec.nat(a);
        bytes memory encB = MichelsonSpec.int_(b);
        assertEq(keccak256(h.asmPair(encA, encB)), keccak256(h.specPair(encA, encB)), "pair asm != spec");
    }

    function testFuzz_packPair_asm_eq_spec(uint256 a, int256 b) public view {
        bytes memory encA = MichelsonSpec.nat(a);
        bytes memory encB = MichelsonSpec.int_(b);
        assertEq(keccak256(h.asmPackPair(encA, encB)), keccak256(h.specPackPair(encA, encB)), "packPair asm != spec");
    }

    function testFuzz_unpackPair_asm_eq_spec(uint256 a, int256 b) public view {
        bytes memory encA = MichelsonSpec.nat(a);
        bytes memory encB = MichelsonSpec.int_(b);
        bytes memory packed = h.specPackPair(encA, encB);
        (bytes memory specL, bytes memory specR) = h.specUnpackPair(packed);
        (bytes memory asmL, bytes memory asmR) = h.asmUnpackPair(packed);
        assertEq(keccak256(asmL), keccak256(specL), "unpackPair left asm != spec");
        assertEq(keccak256(asmR), keccak256(specR), "unpackPair right asm != spec");
    }
}

// ================================================================
// OR: asm == spec
// ================================================================

contract AsmDiffOrTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_unpackOr_left_asm_eq_spec(uint256 n) public view {
        bytes memory packed = h.specPackLeft(MichelsonSpec.nat(n));
        (bool specIsLeft, bytes memory specVal) = h.specUnpackOr(packed);
        (bool asmIsLeft, bytes memory asmVal) = h.asmUnpackOr(packed);
        assertEq(asmIsLeft, specIsLeft);
        assertEq(keccak256(asmVal), keccak256(specVal));
    }

    function testFuzz_unpackOr_right_asm_eq_spec(int256 v) public view {
        bytes memory packed = h.specPackRight(MichelsonSpec.int_(v));
        (bool specIsLeft, bytes memory specVal) = h.specUnpackOr(packed);
        (bool asmIsLeft, bytes memory asmVal) = h.asmUnpackOr(packed);
        assertEq(asmIsLeft, specIsLeft);
        assertEq(keccak256(asmVal), keccak256(specVal));
    }
}

// ================================================================
// OPTION: asm == spec
// ================================================================

contract AsmDiffOptionTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function testFuzz_unpackOption_some_asm_eq_spec(uint256 n) public view {
        bytes memory packed = h.specPackSome(MichelsonSpec.nat(n));
        (bool specIsSome, bytes memory specVal) = h.specUnpackOption(packed);
        (bool asmIsSome, bytes memory asmVal) = h.asmUnpackOption(packed);
        assertEq(asmIsSome, specIsSome);
        assertEq(keccak256(asmVal), keccak256(specVal));
    }

    function test_unpackOption_none_asm_eq_spec() public view {
        bytes memory packed = h.specPackNone();
        (bool specIsSome, bytes memory specVal) = h.specUnpackOption(packed);
        (bool asmIsSome, bytes memory asmVal) = h.asmUnpackOption(packed);
        assertEq(asmIsSome, specIsSome);
        assertEq(keccak256(asmVal), keccak256(specVal));
    }
}

// ================================================================
// LIST: asm == spec
// ================================================================

contract AsmDiffListTest is Test {
    AsmDiffHarness h;
    function setUp() public { h = new AsmDiffHarness(); }

    function test_unpackList_empty_asm_eq_spec() public view {
        bytes[] memory items = new bytes[](0);
        bytes memory packed = h.specPackList(items);
        bytes[] memory specItems = h.specUnpackList(packed);
        bytes[] memory asmItems = h.asmUnpackList(packed);
        assertEq(asmItems.length, specItems.length);
    }

    function testFuzz_unpackList_2nat_asm_eq_spec(uint256 a, uint256 b) public view {
        bytes[] memory items = new bytes[](2);
        items[0] = MichelsonSpec.nat(a);
        items[1] = MichelsonSpec.nat(b);
        bytes memory packed = h.specPackList(items);
        bytes[] memory specItems = h.specUnpackList(packed);
        bytes[] memory asmItems = h.asmUnpackList(packed);
        assertEq(asmItems.length, specItems.length);
        for (uint i = 0; i < specItems.length; i++) {
            assertEq(keccak256(asmItems[i]), keccak256(specItems[i]));
        }
    }
}
