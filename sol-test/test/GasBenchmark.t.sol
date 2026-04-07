// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MichelsonSpec.sol";
import "../src/Michelson.sol";

/// @notice Gas benchmarks for every type, comparing spec vs assembly.
contract GasBenchmark is Test {

    // ================================================================
    // NAT
    // ================================================================

    function test_gas_packNat_0() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.nat(0)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packNat(0); uint256 asm_ = g - gasleft();
        emit log_named_uint("packNat(0) spec", spec);
        emit log_named_uint("packNat(0) asm", asm_);
    }

    function test_gas_packNat_42() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.nat(42)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packNat(42); uint256 asm_ = g - gasleft();
        emit log_named_uint("packNat(42) spec", spec);
        emit log_named_uint("packNat(42) asm", asm_);
    }

    function test_gas_packNat_64() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.nat(64)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packNat(64); uint256 asm_ = g - gasleft();
        emit log_named_uint("packNat(64) spec", spec);
        emit log_named_uint("packNat(64) asm", asm_);
    }

    function test_gas_packNat_max() public {
        uint256 n = type(uint256).max;
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.nat(n)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packNat(n); uint256 asm_ = g - gasleft();
        emit log_named_uint("packNat(max) spec", spec);
        emit log_named_uint("packNat(max) asm", asm_);
    }

    function test_gas_unpackNat_small() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.nat(42));
        uint256 g = gasleft(); MichelsonSpec.toNat(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackNat(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackNat(42) spec", spec);
        emit log_named_uint("unpackNat(42) asm", asm_);
    }

    function test_gas_unpackNat_max() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.nat(type(uint256).max));
        uint256 g = gasleft(); MichelsonSpec.toNat(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackNat(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackNat(max) spec", spec);
        emit log_named_uint("unpackNat(max) asm", asm_);
    }

    // ================================================================
    // INT
    // ================================================================

    function test_gas_packInt_neg1() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.int_(-1)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packInt(-1); uint256 asm_ = g - gasleft();
        emit log_named_uint("packInt(-1) spec", spec);
        emit log_named_uint("packInt(-1) asm", asm_);
    }

    function test_gas_packInt_min() public {
        int256 v = type(int256).min;
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.int_(v)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packInt(v); uint256 asm_ = g - gasleft();
        emit log_named_uint("packInt(min) spec", spec);
        emit log_named_uint("packInt(min) asm", asm_);
    }

    function test_gas_unpackInt_small() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.int_(-42));
        uint256 g = gasleft(); MichelsonSpec.toInt(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackInt(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackInt(-42) spec", spec);
        emit log_named_uint("unpackInt(-42) asm", asm_);
    }

    function test_gas_unpackInt_min() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.int_(type(int256).min));
        uint256 g = gasleft(); MichelsonSpec.toInt(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackInt(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackInt(min) spec", spec);
        emit log_named_uint("unpackInt(min) asm", asm_);
    }

    // ================================================================
    // BOOL
    // ================================================================

    function test_gas_packBool() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.bool_(true)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packBool(true); uint256 asm_ = g - gasleft();
        emit log_named_uint("packBool(true) spec", spec);
        emit log_named_uint("packBool(true) asm", asm_);
    }

    function test_gas_unpackBool() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.bool_(true));
        uint256 g = gasleft(); MichelsonSpec.toBool(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackBool(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackBool spec", spec);
        emit log_named_uint("unpackBool asm", asm_);
    }

    // ================================================================
    // STRING
    // ================================================================

    function test_gas_packString_short() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.string_("hello")); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packString("hello"); uint256 asm_ = g - gasleft();
        emit log_named_uint("packString('hello') spec", spec);
        emit log_named_uint("packString('hello') asm", asm_);
    }

    function test_gas_unpackString_short() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.string_("hello"));
        uint256 g = gasleft(); MichelsonSpec.toString(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackString(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackString('hello') spec", spec);
        emit log_named_uint("unpackString('hello') asm", asm_);
    }

    function test_gas_packString_long() public {
        bytes memory b = new bytes(256);
        for (uint256 i = 0; i < 256; i++) b[i] = bytes1(uint8(65 + i % 26));
        string memory s = string(b);
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.string_(s)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packString(s); uint256 asm_ = g - gasleft();
        emit log_named_uint("packString(256b) spec", spec);
        emit log_named_uint("packString(256b) asm", asm_);
    }

    function test_gas_unpackString_long() public {
        bytes memory b = new bytes(256);
        for (uint256 i = 0; i < 256; i++) b[i] = bytes1(uint8(65 + i % 26));
        string memory s = string(b);
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.string_(s));
        uint256 g = gasleft(); MichelsonSpec.toString(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackString(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackString(256b) spec", spec);
        emit log_named_uint("unpackString(256b) asm", asm_);
    }

    // ================================================================
    // UNIT
    // ================================================================

    function test_gas_packUnit() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.unit_()); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packUnit(); uint256 asm_ = g - gasleft();
        emit log_named_uint("packUnit spec", spec);
        emit log_named_uint("packUnit asm", asm_);
    }

    function test_gas_unpackUnit() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.unit_());
        uint256 g = gasleft(); MichelsonSpec.toUnit(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackUnit(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackUnit spec", spec);
        emit log_named_uint("unpackUnit asm", asm_);
    }

    // ================================================================
    // MUTEZ
    // ================================================================

    function test_gas_packMutez() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.nat(1000000)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packMutez(1000000); uint256 asm_ = g - gasleft();
        emit log_named_uint("packMutez(1M) spec", spec);
        emit log_named_uint("packMutez(1M) asm", asm_);
    }

    function test_gas_unpackMutez() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.nat(1000000));
        uint256 g = gasleft(); MichelsonSpec.toMutez(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackMutez(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackMutez(1M) spec", spec);
        emit log_named_uint("unpackMutez(1M) asm", asm_);
    }

    function test_gas_unpackMutez_max() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.nat(uint256(type(uint64).max / 2)));
        uint256 g = gasleft(); MichelsonSpec.toMutez(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackMutez(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackMutez(max) spec", spec);
        emit log_named_uint("unpackMutez(max) asm", asm_);
    }

    // ================================================================
    // TIMESTAMP
    // ================================================================

    function test_gas_packTimestamp() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.int_(-1000000)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packTimestamp(-1000000); uint256 asm_ = g - gasleft();
        emit log_named_uint("packTimestamp(-1M) spec", spec);
        emit log_named_uint("packTimestamp(-1M) asm", asm_);
    }

    function test_gas_unpackTimestamp() public {
        bytes memory p = MichelsonSpec.pack(MichelsonSpec.int_(-1000000));
        uint256 g = gasleft(); MichelsonSpec.toTimestamp(MichelsonSpec.unpack(p)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackTimestamp(p); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackTimestamp(-1M) spec", spec);
        emit log_named_uint("unpackTimestamp(-1M) asm", asm_);
    }

    // ================================================================
    // PAIR
    // ================================================================

    function test_gas_packPair() public {
        bytes memory a = MichelsonSpec.nat(42);
        bytes memory b = MichelsonSpec.string_("hello");
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.pair(a, b)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packPair(a, b); uint256 asm_ = g - gasleft();
        emit log_named_uint("packPair spec", spec);
        emit log_named_uint("packPair asm", asm_);
    }

    function test_gas_unpackPair() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.pair(MichelsonSpec.nat(42), MichelsonSpec.string_("hello")));
        uint256 g = gasleft(); MichelsonSpec.toPair(MichelsonSpec.unpack(packed)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackPair(packed); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackPair spec", spec);
        emit log_named_uint("unpackPair asm", asm_);
    }

    // ================================================================
    // OR
    // ================================================================

    function test_gas_packLeft() public {
        bytes memory a = MichelsonSpec.nat(42);
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.left(a)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packLeft(a); uint256 asm_ = g - gasleft();
        emit log_named_uint("packLeft spec", spec);
        emit log_named_uint("packLeft asm", asm_);
    }

    function test_gas_packRight() public {
        bytes memory b = MichelsonSpec.string_("hello");
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.right(b)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packRight(b); uint256 asm_ = g - gasleft();
        emit log_named_uint("packRight spec", spec);
        emit log_named_uint("packRight asm", asm_);
    }

    function test_gas_unpackOr_left() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.left(MichelsonSpec.nat(42)));
        uint256 g = gasleft(); MichelsonSpec.toOr(MichelsonSpec.unpack(packed)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackOr(packed); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackOr(left) spec", spec);
        emit log_named_uint("unpackOr(left) asm", asm_);
    }

    function test_gas_unpackOr_right() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.right(MichelsonSpec.string_("hello")));
        uint256 g = gasleft(); MichelsonSpec.toOr(MichelsonSpec.unpack(packed)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackOr(packed); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackOr(right) spec", spec);
        emit log_named_uint("unpackOr(right) asm", asm_);
    }

    // ================================================================
    // OPTION
    // ================================================================

    function test_gas_packSome() public {
        bytes memory a = MichelsonSpec.nat(42);
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.some(a)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packSome(a); uint256 asm_ = g - gasleft();
        emit log_named_uint("packSome spec", spec);
        emit log_named_uint("packSome asm", asm_);
    }

    function test_gas_packNone() public {
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.none()); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packNone(); uint256 asm_ = g - gasleft();
        emit log_named_uint("packNone spec", spec);
        emit log_named_uint("packNone asm", asm_);
    }

    function test_gas_unpackOption_some() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.some(MichelsonSpec.nat(42)));
        uint256 g = gasleft(); MichelsonSpec.toOption(MichelsonSpec.unpack(packed)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackOption(packed); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackOption(some) spec", spec);
        emit log_named_uint("unpackOption(some) asm", asm_);
    }

    function test_gas_unpackOption_none() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.none());
        uint256 g = gasleft(); MichelsonSpec.toOption(MichelsonSpec.unpack(packed)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackOption(packed); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackOption(none) spec", spec);
        emit log_named_uint("unpackOption(none) asm", asm_);
    }

    // ================================================================
    // LIST
    // ================================================================

    function test_gas_packList() public {
        bytes[] memory items = new bytes[](3);
        items[0] = MichelsonSpec.nat(1);
        items[1] = MichelsonSpec.nat(2);
        items[2] = MichelsonSpec.nat(3);
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.list(items)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packList(items); uint256 asm_ = g - gasleft();
        emit log_named_uint("packList({1,2,3}) spec", spec);
        emit log_named_uint("packList({1,2,3}) asm", asm_);
    }

    // ================================================================
    // BYTES
    // ================================================================

    function test_gas_packBytes() public {
        bytes memory data = hex"deadbeef";
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.bytes_(data)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packBytes(data); uint256 asm_ = g - gasleft();
        emit log_named_uint("packBytes(4b) spec", spec);
        emit log_named_uint("packBytes(4b) asm", asm_);
    }

    function test_gas_unpackBytes() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.bytes_(hex"deadbeef"));
        uint256 g = gasleft(); MichelsonSpec.toBytes(MichelsonSpec.unpack(packed)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackBytes(packed); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackBytes(4b) spec", spec);
        emit log_named_uint("unpackBytes(4b) asm", asm_);
    }

    // ================================================================
    // ADDRESS
    // ================================================================

    function test_gas_packAddress() public {
        bytes memory addr = hex"00006b82198cb179e8306c1bedd08f12dc863f328886";
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.address_(addr)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packAddress(addr); uint256 asm_ = g - gasleft();
        emit log_named_uint("packAddress spec", spec);
        emit log_named_uint("packAddress asm", asm_);
    }

    function test_gas_unpackAddress() public {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.address_(hex"00006b82198cb179e8306c1bedd08f12dc863f328886"));
        uint256 g = gasleft(); MichelsonSpec.toAddress(MichelsonSpec.unpack(packed)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackAddress(packed); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackAddress spec", spec);
        emit log_named_uint("unpackAddress asm", asm_);
    }

    // ================================================================
    // CHAIN_ID
    // ================================================================

    function test_gas_packChainId() public {
        bytes memory cid = hex"7a06a770";
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.bytes_(cid)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packChainId(cid); uint256 asm_ = g - gasleft();
        emit log_named_uint("packChainId spec", spec);
        emit log_named_uint("packChainId asm", asm_);
    }

    // ================================================================
    // MAP
    // ================================================================

    function test_gas_packMap() public {
        bytes[] memory elts = new bytes[](2);
        elts[0] = MichelsonSpec.elt(MichelsonSpec.nat(1), MichelsonSpec.string_("a"));
        elts[1] = MichelsonSpec.elt(MichelsonSpec.nat(2), MichelsonSpec.string_("b"));
        uint256 g = gasleft(); MichelsonSpec.pack(MichelsonSpec.map(elts)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.packMap(elts); uint256 asm_ = g - gasleft();
        emit log_named_uint("packMap(2 elts) spec", spec);
        emit log_named_uint("packMap(2 elts) asm", asm_);
    }

    function test_gas_unpackList() public {
        bytes[] memory items = new bytes[](3);
        items[0] = MichelsonSpec.nat(1);
        items[1] = MichelsonSpec.nat(2);
        items[2] = MichelsonSpec.nat(3);
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.list(items));
        uint256 g = gasleft(); MichelsonSpec.toList(MichelsonSpec.unpack(packed)); uint256 spec = g - gasleft();
        g = gasleft(); Michelson.unpackList(packed); uint256 asm_ = g - gasleft();
        emit log_named_uint("unpackList({1,2,3}) spec", spec);
        emit log_named_uint("unpackList({1,2,3}) asm", asm_);
    }
}
