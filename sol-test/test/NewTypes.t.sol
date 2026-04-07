// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MichelsonSpec.sol";

contract NewTypesHarness {
    // Bytes
    function packBytes(bytes memory data) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bytes_(data)); }
    function unpackBytes(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toBytes(MichelsonSpec.unpack(packed)); }
    function bytes_(bytes memory data) external pure returns (bytes memory) { return MichelsonSpec.bytes_(data); }

    // Address
    function packAddress(bytes memory addr) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.address_(addr)); }
    function unpackAddress(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toAddress(MichelsonSpec.unpack(packed)); }
    function address_(bytes memory addr) external pure returns (bytes memory) { return MichelsonSpec.address_(addr); }

    // Key_hash
    function packKeyHash(bytes memory kh) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.keyHash(kh)); }
    function unpackKeyHash(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toKeyHash(MichelsonSpec.unpack(packed)); }

    // Key
    function packKey(bytes memory k) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.key(k)); }
    function unpackKey(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toKey(MichelsonSpec.unpack(packed)); }

    // Signature
    function packSignature(bytes memory sig) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.signature_(sig)); }
    function unpackSignature(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toSignature(MichelsonSpec.unpack(packed)); }

    // Chain_id
    function packChainId(bytes memory cid) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bytes_(cid)); }
    function unpackChainId(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toBytes(MichelsonSpec.unpack(packed)); }

    // Contract
    function packContract(bytes memory data) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.bytes_(data)); }
    function unpackContract(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toBytes(MichelsonSpec.unpack(packed)); }

    // Map
    function elt(bytes memory k, bytes memory v) external pure returns (bytes memory) { return MichelsonSpec.elt(k, v); }
    function map(bytes[] memory elts) external pure returns (bytes memory) { return MichelsonSpec.map(elts); }
    function packMap(bytes[] memory elts) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.map(elts)); }
    function unpackMap(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toMap(MichelsonSpec.unpack(packed)); }

    // Set
    function set(bytes[] memory items) external pure returns (bytes memory) { return MichelsonSpec.set(items); }
    function packSet(bytes[] memory items) external pure returns (bytes memory) { return MichelsonSpec.pack(MichelsonSpec.set(items)); }
    function unpackSet(bytes memory packed) external pure returns (bytes memory) { return MichelsonSpec.toSet(MichelsonSpec.unpack(packed)); }

    // Inner encoders for building test values
    function nat(uint256 n) external pure returns (bytes memory) { return MichelsonSpec.nat(n); }
    function string_(string memory s) external pure returns (bytes memory) { return MichelsonSpec.string_(s); }
}

// ================================================================
// BYTES
// ================================================================

contract MichelsonBytesTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

    // Known vector from octez-client: PACK(0xdeadbeef) = 0x050a00000004deadbeef
    function test_packBytes_deadbeef() public view {
        assertEq(h.packBytes(hex"deadbeef"), hex"050a00000004deadbeef");
    }

    // Empty bytes: 0x050a00000000
    function test_packBytes_empty() public view {
        assertEq(h.packBytes(hex""), hex"050a00000000");
    }

    // Decode vectors
    function test_unpackBytes_deadbeef() public view {
        assertEq(h.unpackBytes(hex"050a00000004deadbeef"), hex"deadbeef");
    }

    function test_unpackBytes_empty() public view {
        bytes memory result = h.unpackBytes(hex"050a00000000");
        assertEq(result.length, 0);
    }

    // Inner encoder
    function test_encodeBytes() public view {
        assertEq(h.bytes_(hex"deadbeef"), hex"0a00000004deadbeef");
    }

    // Fuzz roundtrip
    function testFuzz_roundtrip_bytes(bytes memory data) public view {
        assertEq(keccak256(h.unpackBytes(h.packBytes(data))), keccak256(data));
    }

    // Invalid inputs
    function test_unpackBytes_truncated() public {
        vm.expectRevert(MichelsonSpec.InputTruncated.selector);
        h.unpackBytes(hex"050a");
    }

    function test_unpackBytes_wrong_version() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.InvalidVersionByte.selector, uint8(0x06)));
        h.unpackBytes(hex"060a00000000");
    }

    function test_unpackBytes_wrong_tag() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.UnexpectedNodeTag.selector, uint8(0x0A), uint8(0x01)));
        h.unpackBytes(hex"050100000000");
    }

    function test_unpackBytes_trailing() public {
        vm.expectRevert(abi.encodeWithSelector(MichelsonSpec.TrailingBytes.selector, uint256(5), uint256(6)));
        h.unpackBytes(hex"050a0000000000");
    }
}

// ================================================================
// MAP
// ================================================================

contract MichelsonMapTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

    // Known vector from octez-client:
    // { Elt 1 "a" ; Elt 2 "b" } of type 'map nat string'
    // = 0x0502000000140704000101000000016107040002010000000162
    function test_packMap_elt_1_a_2_b() public view {
        bytes memory elt1 = h.elt(h.nat(1), h.string_("a"));
        bytes memory elt2 = h.elt(h.nat(2), h.string_("b"));
        bytes[] memory elts = new bytes[](2);
        elts[0] = elt1;
        elts[1] = elt2;
        assertEq(h.packMap(elts), hex"0502000000140704000101000000016107040002010000000162");
    }

    // elt
    function test_elt() public view {
        bytes memory e = h.elt(h.nat(1), h.string_("a"));
        assertEq(e, hex"07040001010000000161");
    }

    // Empty map
    function test_packMap_empty() public view {
        bytes[] memory elts = new bytes[](0);
        assertEq(h.packMap(elts), hex"050200000000");
    }

    // Roundtrip: unpackMap returns the raw payload
    function test_unpackMap() public view {
        bytes memory payload = h.unpackMap(hex"0502000000140704000101000000016107040002010000000162");
        assertEq(payload, hex"0704000101000000016107040002010000000162");
    }

    function test_unpackMap_empty() public view {
        bytes memory payload = h.unpackMap(hex"050200000000");
        assertEq(payload.length, 0);
    }
}

// ================================================================
// SET
// ================================================================

contract MichelsonSetTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

    // Known vector from octez-client:
    // { 1 ; 2 ; 3 } of type 'set nat' = 0x050200000006000100020003
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
        bytes memory payload = h.unpackSet(hex"050200000006000100020003");
        assertEq(payload, hex"000100020003");
    }
}

// ================================================================
// ADDRESS
// ================================================================

contract MichelsonAddressTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

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

    // Inner encoder
    function test_encodeAddress() public view {
        bytes memory addr = hex"00006b82198cb179e8306c1bedd08f12dc863f328886";
        assertEq(h.address_(addr), hex"0a0000001600006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    // Fuzz roundtrip
    function testFuzz_roundtrip_address(bytes memory addr) public view {
        assertEq(keccak256(h.unpackAddress(h.packAddress(addr))), keccak256(addr));
    }
}

// ================================================================
// KEY_HASH
// ================================================================

contract MichelsonKeyHashTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

    function test_packKeyHash_tz1() public view {
        bytes memory kh = hex"006b82198cb179e8306c1bedd08f12dc863f328886";
        assertEq(h.packKeyHash(kh), hex"050a00000015006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    function test_unpackKeyHash_tz1() public view {
        bytes memory kh = h.unpackKeyHash(hex"050a00000015006b82198cb179e8306c1bedd08f12dc863f328886");
        assertEq(kh, hex"006b82198cb179e8306c1bedd08f12dc863f328886");
    }

    // Fuzz roundtrip
    function testFuzz_roundtrip_keyhash(bytes memory kh) public view {
        assertEq(keccak256(h.unpackKeyHash(h.packKeyHash(kh))), keccak256(kh));
    }
}

// ================================================================
// KEY
// ================================================================

contract MichelsonKeyTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

    function test_packKey_ed25519() public view {
        bytes memory k = hex"00d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af";
        assertEq(h.packKey(k), hex"050a0000002100d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af");
    }

    function test_unpackKey_ed25519() public view {
        bytes memory k = h.unpackKey(hex"050a0000002100d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af");
        assertEq(k, hex"00d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af");
    }

    // Fuzz roundtrip
    function testFuzz_roundtrip_key(bytes memory k) public view {
        assertEq(keccak256(h.unpackKey(h.packKey(k))), keccak256(k));
    }
}

// ================================================================
// SIGNATURE
// ================================================================

contract MichelsonSignatureTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

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

    // Fuzz roundtrip
    function testFuzz_roundtrip_signature(bytes memory sig) public view {
        assertEq(keccak256(h.unpackSignature(h.packSignature(sig))), keccak256(sig));
    }
}

// ================================================================
// CHAIN_ID
// ================================================================

contract MichelsonChainIdTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

    function test_packChainId_mainnet() public view {
        bytes memory cid = hex"7a06a770";
        assertEq(h.packChainId(cid), hex"050a000000047a06a770");
    }

    function test_unpackChainId_mainnet() public view {
        bytes memory cid = h.unpackChainId(hex"050a000000047a06a770");
        assertEq(cid, hex"7a06a770");
    }

    // Fuzz roundtrip
    function testFuzz_roundtrip_chainid(bytes memory cid) public view {
        assertEq(keccak256(h.unpackChainId(h.packChainId(cid))), keccak256(cid));
    }
}

// ================================================================
// CONTRACT
// ================================================================

contract MichelsonContractTest is Test {
    NewTypesHarness h;
    function setUp() public { h = new NewTypesHarness(); }

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

    // Fuzz roundtrip
    function testFuzz_roundtrip_contract(bytes memory data) public view {
        assertEq(keccak256(h.unpackContract(h.packContract(data))), keccak256(data));
    }
}
