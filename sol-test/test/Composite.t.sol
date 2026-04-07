// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MichelsonSpec.sol";

contract CompositeHarness {
    function nat(uint256 n) external pure returns (bytes memory) { return MichelsonSpec.nat(n); }
    function int_(int256 v) external pure returns (bytes memory) { return MichelsonSpec.int_(v); }
    function bool_(bool v) external pure returns (bytes memory) { return MichelsonSpec.bool_(v); }
    function string_(string memory s) external pure returns (bytes memory) { return MichelsonSpec.string_(s); }
    function pair(bytes memory a, bytes memory b) external pure returns (bytes memory) { return MichelsonSpec.pair(a, b); }
    function left(bytes memory a) external pure returns (bytes memory) { return MichelsonSpec.left(a); }
    function right(bytes memory b) external pure returns (bytes memory) { return MichelsonSpec.right(b); }
    function some(bytes memory a) external pure returns (bytes memory) { return MichelsonSpec.some(a); }
    function none() external pure returns (bytes memory) { return MichelsonSpec.none(); }
    function list(bytes[] memory items) external pure returns (bytes memory) { return MichelsonSpec.list(items); }
    function bytes_(bytes memory data) external pure returns (bytes memory) { return MichelsonSpec.bytes_(data); }
    function elt(bytes memory k, bytes memory v) external pure returns (bytes memory) { return MichelsonSpec.elt(k, v); }
    function map(bytes[] memory elts) external pure returns (bytes memory) { return MichelsonSpec.map(elts); }
    function set(bytes[] memory items) external pure returns (bytes memory) { return MichelsonSpec.set(items); }

    function packPair(bytes memory a, bytes memory b) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.pair(a, b)); }
    function packLeft(bytes memory a) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.left(a)); }
    function packRight(bytes memory b) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.right(b)); }
    function packSome(bytes memory a) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.some(a)); }
    function packNone() external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.none()); }
    function packList(bytes[] memory items) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.list(items)); }

    function unpackPair(bytes memory p) external pure returns (bytes memory, bytes memory) { return MichelsonSpec.toPair(MichelsonSpec.unpack(p)); }
    function unpackOr(bytes memory p) external pure returns (bool, bytes memory) { return MichelsonSpec.toOr(MichelsonSpec.unpack(p)); }
    function unpackOption(bytes memory p) external pure returns (bool, bytes memory) { return MichelsonSpec.toOption(MichelsonSpec.unpack(p)); }
    function unpackList(bytes memory p) external pure returns (bytes memory) { return MichelsonSpec.toList(MichelsonSpec.unpack(p)); }
}

contract CompositePairTest is Test {
    CompositeHarness h;
    function setUp() public { h = new CompositeHarness(); }

    // Known vector: Pair 42 "hello" -> 0x050707002a010000000568656c6c6f
    function test_packPair_nat_string() public view {
        bytes memory encA = h.nat(42);
        bytes memory encB = h.string_("hello");
        assertEq(h.packPair(encA, encB), hex"050707002a010000000568656c6c6f");
    }

    function test_unpackPair_nat_string() public view {
        (bytes memory a, bytes memory b) = h.unpackPair(hex"050707002a010000000568656c6c6f");
        assertEq(a, hex"002a");           // nat(42) = 0x00 0x2a
        assertEq(b, hex"010000000568656c6c6f"); // string_("hello")
    }

    // Roundtrip
    function testFuzz_pair_roundtrip(uint256 n, int256 v) public view {
        bytes memory encA = h.nat(n);
        bytes memory encB = h.int_(v);
        bytes memory packed = h.packPair(encA, encB);
        (bytes memory decA, bytes memory decB) = h.unpackPair(packed);
        assertEq(keccak256(decA), keccak256(encA));
        assertEq(keccak256(decB), keccak256(encB));
    }

    // Nested pair: Pair(1, Pair(2, 3))
    function test_nested_pair() public view {
        bytes memory inner = h.pair(h.nat(2), h.nat(3));
        bytes memory packed = h.packPair(h.nat(1), inner);
        (bytes memory a, bytes memory b) = h.unpackPair(packed);
        assertEq(a, h.nat(1));
        assertEq(keccak256(b), keccak256(inner));
    }
}

contract CompositeOrTest is Test {
    CompositeHarness h;
    function setUp() public { h = new CompositeHarness(); }

    // Known vectors
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

    // Roundtrip
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

contract CompositeOptionTest is Test {
    CompositeHarness h;
    function setUp() public { h = new CompositeHarness(); }

    // Known vectors
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

    // Roundtrip
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

contract CompositeListTest is Test {
    CompositeHarness h;
    function setUp() public { h = new CompositeHarness(); }

    // Known vectors: {1;2;3} -> 0x050200000006000100020003
    function test_packList_123() public view {
        bytes[] memory items = new bytes[](3);
        items[0] = h.nat(1);
        items[1] = h.nat(2);
        items[2] = h.nat(3);
        assertEq(h.packList(items), hex"050200000006000100020003");
    }

    // Empty list: {} -> 0x050200000000
    function test_packList_empty() public view {
        bytes[] memory items = new bytes[](0);
        assertEq(h.packList(items), hex"050200000000");
    }

    function test_unpackList_123() public view {
        bytes memory payload = h.unpackList(hex"050200000006000100020003");
        assertEq(payload, hex"000100020003");
    }

    function test_unpackList_empty() public view {
        bytes memory payload = h.unpackList(hex"050200000000");
        assertEq(payload.length, 0);
    }

    // Roundtrip
    function test_list_roundtrip() public view {
        bytes[] memory items = new bytes[](3);
        items[0] = h.nat(100);
        items[1] = h.nat(200);
        items[2] = h.nat(300);
        bytes memory packed = h.packList(items);
        bytes memory payload = h.unpackList(packed);
        // Payload should be the concatenation of the items
        bytes memory expected = abi.encodePacked(items[0], items[1], items[2]);
        assertEq(keccak256(payload), keccak256(expected));
    }
}
