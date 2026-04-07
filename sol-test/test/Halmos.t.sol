// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MichelsonSpec.sol";
import "../src/Michelson.sol";

/// @notice Symbolic verification: prove asm == spec for ALL inputs.
///         Run with: halmos --function check_ --loop 40 --solver-timeout-assertion 60000
contract HalmosAsmEquivalence is Test {

    // ================================================================
    // NAT: asm unpackNat == spec toNat(unpack()) for all valid PACK bytes
    // ================================================================

    function check_unpackNat_asm_eq_spec(uint256 n) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.nat(n));
        uint256 specVal = MichelsonSpec.toNat(MichelsonSpec.unpack(packed));
        uint256 asmVal = Michelson.unpackNat(packed);
        assert(asmVal == specVal);
    }

    function check_unpackNat_asm_roundtrip(uint256 n) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.nat(n));
        assert(Michelson.unpackNat(packed) == n);
    }

    // ================================================================
    // INT: asm unpackInt == spec toInt(unpack()) for all valid PACK bytes
    // ================================================================

    function check_unpackInt_asm_eq_spec(int256 v) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.int_(v));
        int256 specVal = MichelsonSpec.toInt(MichelsonSpec.unpack(packed));
        int256 asmVal = Michelson.unpackInt(packed);
        assert(asmVal == specVal);
    }

    function check_unpackInt_asm_roundtrip(int256 v) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.int_(v));
        assert(Michelson.unpackInt(packed) == v);
    }

    // ================================================================
    // NAT: spec roundtrip (Lean-proven, here as a sanity check)
    // ================================================================

    function check_spec_nat_roundtrip(uint256 n) public pure {
        assert(MichelsonSpec.toNat(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.nat(n)))) == n);
    }

    function check_spec_int_roundtrip(int256 v) public pure {
        assert(MichelsonSpec.toInt(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.int_(v)))) == v);
    }

    // ================================================================
    // BOOL: spec roundtrip + asm equivalence
    // ================================================================

    function check_spec_bool_roundtrip(bool v) public pure {
        assert(MichelsonSpec.toBool(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.bool_(v)))) == v);
    }

    function check_unpackBool_asm_eq_spec(bool v) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.bool_(v));
        bool specVal = MichelsonSpec.toBool(MichelsonSpec.unpack(packed));
        bool asmVal = uint256(Michelson.packToEVMBool(packed)) != 0;
        assert(asmVal == specVal);
    }

    // ================================================================
    // STRING: spec roundtrip
    // ================================================================

    function check_spec_string_roundtrip(string memory s) public pure {
        string memory decoded = MichelsonSpec.toString(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.string_(s))));
        assert(keccak256(bytes(decoded)) == keccak256(bytes(s)));
    }

    // ================================================================
    // MUTEZ: spec roundtrip + asm equivalence
    // ================================================================

    function check_spec_mutez_roundtrip(uint64 v) public pure {
        assert(MichelsonSpec.toMutez(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.nat(uint256(v))))) == v);
    }

    function check_unpackMutez_asm_eq_spec(uint64 v) public pure {
        vm.assume(v <= type(uint64).max / 2);
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.nat(uint256(v)));
        uint64 specVal = MichelsonSpec.toMutez(MichelsonSpec.unpack(packed));
        uint256 asmVal = Michelson.unpackNat(packed);
        assert(uint256(specVal) == asmVal);
    }

    // ================================================================
    // TIMESTAMP: spec roundtrip + asm equivalence
    // ================================================================

    function check_spec_timestamp_roundtrip(int64 v) public pure {
        assert(MichelsonSpec.toTimestamp(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.int_(int256(v))))) == v);
    }

    function check_unpackTimestamp_asm_eq_spec(int64 v) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.int_(int256(v)));
        int64 specVal = MichelsonSpec.toTimestamp(MichelsonSpec.unpack(packed));
        int256 asmVal = Michelson.unpackInt(packed);
        assert(int256(specVal) == asmVal);
    }

    // ================================================================
    // PACK ENCODERS: asm packNat/packInt == spec pack(nat())/pack(int_())
    // ================================================================

    function check_packNat_asm_eq_spec(uint256 n) public pure {
        bytes memory specPacked = MichelsonSpec.pack(MichelsonSpec.nat(n));
        bytes memory asmPacked = Michelson.packNat(n);
        assert(keccak256(specPacked) == keccak256(asmPacked));
    }

    function check_packInt_asm_eq_spec(int256 v) public pure {
        bytes memory specPacked = MichelsonSpec.pack(MichelsonSpec.int_(v));
        bytes memory asmPacked = Michelson.packInt(v);
        assert(keccak256(specPacked) == keccak256(asmPacked));
    }

    // ================================================================
    // PAIR: spec roundtrip + asm equivalence
    // ================================================================

    function check_pair_roundtrip(uint256 a, int256 b) public pure {
        bytes memory encA = MichelsonSpec.nat(a);
        bytes memory encB = MichelsonSpec.int_(b);
        (bytes memory decA, bytes memory decB) = MichelsonSpec.toPair(
            MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.pair(encA, encB)))
        );
        assert(keccak256(decA) == keccak256(encA));
        assert(keccak256(decB) == keccak256(encB));
    }

    function check_unpackPair_asm_eq_spec(uint256 a, int256 b) public pure {
        bytes memory encA = MichelsonSpec.nat(a);
        bytes memory encB = MichelsonSpec.int_(b);
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.pair(encA, encB));
        (bytes memory specL, bytes memory specR) = MichelsonSpec.toPair(MichelsonSpec.unpack(packed));
        (bytes memory asmL, bytes memory asmR) = Michelson.unpackPair(packed);
        assert(keccak256(asmL) == keccak256(specL));
        assert(keccak256(asmR) == keccak256(specR));
    }

    // ================================================================
    // OR: spec roundtrip + asm equivalence
    // ================================================================

    function check_or_left_roundtrip(uint256 n) public pure {
        bytes memory enc = MichelsonSpec.nat(n);
        (bool isLeft, bytes memory val) = MichelsonSpec.toOr(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.left(enc))));
        assert(isLeft);
        assert(keccak256(val) == keccak256(enc));
    }

    function check_or_right_roundtrip(int256 v) public pure {
        bytes memory enc = MichelsonSpec.int_(v);
        (bool isLeft, bytes memory val) = MichelsonSpec.toOr(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.right(enc))));
        assert(!isLeft);
        assert(keccak256(val) == keccak256(enc));
    }

    function check_unpackOr_left_asm_eq_spec(uint256 n) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.left(MichelsonSpec.nat(n)));
        (bool specIsLeft, bytes memory specVal) = MichelsonSpec.toOr(MichelsonSpec.unpack(packed));
        (bool asmIsLeft, bytes memory asmVal) = Michelson.unpackOr(packed);
        assert(asmIsLeft == specIsLeft);
        assert(keccak256(asmVal) == keccak256(specVal));
    }

    function check_unpackOr_right_asm_eq_spec(int256 v) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.right(MichelsonSpec.int_(v)));
        (bool specIsLeft, bytes memory specVal) = MichelsonSpec.toOr(MichelsonSpec.unpack(packed));
        (bool asmIsLeft, bytes memory asmVal) = Michelson.unpackOr(packed);
        assert(asmIsLeft == specIsLeft);
        assert(keccak256(asmVal) == keccak256(specVal));
    }

    // ================================================================
    // OPTION: spec roundtrip + asm equivalence
    // ================================================================

    function check_option_some_roundtrip(uint256 n) public pure {
        bytes memory enc = MichelsonSpec.nat(n);
        (bool isSome, bytes memory val) = MichelsonSpec.toOption(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.some(enc))));
        assert(isSome);
        assert(keccak256(val) == keccak256(enc));
    }

    function check_option_none_roundtrip() public pure {
        (bool isSome,) = MichelsonSpec.toOption(MichelsonSpec.unpack(MichelsonSpec.pack(MichelsonSpec.none())));
        assert(!isSome);
    }

    function check_unpackOption_some_asm_eq_spec(uint256 n) public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.some(MichelsonSpec.nat(n)));
        (bool specIsSome, bytes memory specVal) = MichelsonSpec.toOption(MichelsonSpec.unpack(packed));
        (bool asmIsSome, bytes memory asmVal) = Michelson.unpackOption(packed);
        assert(asmIsSome == specIsSome);
        assert(keccak256(asmVal) == keccak256(specVal));
    }

    function check_unpackOption_none_asm_eq_spec() public pure {
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.none());
        (bool specIsSome, bytes memory specVal) = MichelsonSpec.toOption(MichelsonSpec.unpack(packed));
        (bool asmIsSome, bytes memory asmVal) = Michelson.unpackOption(packed);
        assert(asmIsSome == specIsSome);
        assert(keccak256(asmVal) == keccak256(specVal));
    }

    // ================================================================
    // LIST: spec roundtrip + asm equivalence
    // ================================================================

    function check_list_empty_roundtrip() public pure {
        bytes[] memory items = new bytes[](0);
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.list(items));
        bytes[] memory decoded = MichelsonSpec.toList(MichelsonSpec.unpack(packed));
        assert(decoded.length == 0);
    }

    function check_list_1nat_roundtrip(uint256 a) public pure {
        bytes[] memory items = new bytes[](1);
        items[0] = MichelsonSpec.nat(a);
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.list(items));
        bytes[] memory decoded = MichelsonSpec.toList(MichelsonSpec.unpack(packed));
        assert(decoded.length == 1);
        assert(keccak256(decoded[0]) == keccak256(items[0]));
    }

    function check_list_2nat_roundtrip(uint256 a, uint256 b) public pure {
        bytes[] memory items = new bytes[](2);
        items[0] = MichelsonSpec.nat(a);
        items[1] = MichelsonSpec.nat(b);
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.list(items));
        bytes[] memory decoded = MichelsonSpec.toList(MichelsonSpec.unpack(packed));
        assert(decoded.length == 2);
        assert(keccak256(decoded[0]) == keccak256(items[0]));
        assert(keccak256(decoded[1]) == keccak256(items[1]));
    }

    function check_unpackList_empty_asm_eq_spec() public pure {
        bytes[] memory items = new bytes[](0);
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.list(items));
        bytes[] memory specItems = MichelsonSpec.toList(MichelsonSpec.unpack(packed));
        bytes[] memory asmItems = Michelson.unpackList(packed);
        assert(asmItems.length == specItems.length);
    }

    function check_unpackList_2nat_asm_eq_spec(uint256 a, uint256 b) public pure {
        bytes[] memory items = new bytes[](2);
        items[0] = MichelsonSpec.nat(a);
        items[1] = MichelsonSpec.nat(b);
        bytes memory packed = MichelsonSpec.pack(MichelsonSpec.list(items));
        bytes[] memory specItems = MichelsonSpec.toList(MichelsonSpec.unpack(packed));
        bytes[] memory asmItems = Michelson.unpackList(packed);
        assert(asmItems.length == specItems.length);
        for (uint i = 0; i < specItems.length; i++) {
            assert(keccak256(asmItems[i]) == keccak256(specItems[i]));
        }
    }
}

/// @notice Adversarial Halmos tests: feed arbitrary bytes to decoders.
contract HalmosAdversarial is Test {

    function _specUnpackNat(bytes memory packed) external pure returns (uint256) {
        return MichelsonSpec.toNat(MichelsonSpec.unpack(packed));
    }

    function _asmUnpackNat(bytes memory packed) external pure returns (uint256) {
        return Michelson.unpackNat(packed);
    }

    function _specUnpackInt(bytes memory packed) external pure returns (int256) {
        return MichelsonSpec.toInt(MichelsonSpec.unpack(packed));
    }

    function _asmUnpackInt(bytes memory packed) external pure returns (int256) {
        return Michelson.unpackInt(packed);
    }

    function check_unpackNat_asm_eq_spec_arbitrary(bytes memory packed) public view {
        bool specOk = true;
        uint256 specVal;
        try this._specUnpackNat(packed) returns (uint256 v) {
            specVal = v;
        } catch {
            specOk = false;
        }
        if (specOk) {
            uint256 asmVal = this._asmUnpackNat(packed);
            assert(asmVal == specVal);
        }
    }

    function check_unpackNat_asm_rejects_when_spec_rejects(bytes memory packed) public view {
        bool specOk = true;
        try this._specUnpackNat(packed) {} catch { specOk = false; }
        if (!specOk) {
            bool asmOk = true;
            try this._asmUnpackNat(packed) {} catch { asmOk = false; }
            assert(!asmOk);
        }
    }

    function check_unpackInt_asm_eq_spec_arbitrary(bytes memory packed) public view {
        bool specOk = true;
        int256 specVal;
        try this._specUnpackInt(packed) returns (int256 v) {
            specVal = v;
        } catch {
            specOk = false;
        }
        if (specOk) {
            int256 asmVal = this._asmUnpackInt(packed);
            assert(asmVal == specVal);
        }
    }

    function check_unpackInt_asm_rejects_when_spec_rejects(bytes memory packed) public view {
        bool specOk = true;
        try this._specUnpackInt(packed) {} catch { specOk = false; }
        if (!specOk) {
            bool asmOk = true;
            try this._asmUnpackInt(packed) {} catch { asmOk = false; }
            assert(!asmOk);
        }
    }
}

/// @notice Symbolic roundtrip checks for binary (bytes-node) types.
contract HalmosBinaryRoundtrip is Test {

    // ================================================================
    // ADDRESS: pack/unpack roundtrip
    // ================================================================

    function check_packAddress_roundtrip(bytes memory addr) public pure {
        vm.assume(addr.length > 0 && addr.length <= 100);
        bytes memory packed = Michelson.packAddress(addr);
        bytes memory decoded = Michelson.unpackAddress(packed);
        assertEq(decoded, addr);
    }

    // ================================================================
    // BYTES: pack/unpack roundtrip
    // ================================================================

    function check_packBytes_roundtrip(bytes memory data) public pure {
        vm.assume(data.length <= 100);
        bytes memory packed = Michelson.packBytes(data);
        bytes memory decoded = Michelson.unpackBytes(packed);
        assertEq(decoded, data);
    }

    // ================================================================
    // KEY_HASH: pack/unpack roundtrip
    // ================================================================

    function check_packKeyHash_roundtrip(bytes memory kh) public pure {
        vm.assume(kh.length > 0 && kh.length <= 100);
        bytes memory packed = Michelson.packKeyHash(kh);
        bytes memory decoded = Michelson.unpackKeyHash(packed);
        assertEq(decoded, kh);
    }

    // ================================================================
    // KEY: pack/unpack roundtrip
    // ================================================================

    function check_packKey_roundtrip(bytes memory k) public pure {
        vm.assume(k.length > 0 && k.length <= 100);
        bytes memory packed = Michelson.packKey(k);
        bytes memory decoded = Michelson.unpackKey(packed);
        assertEq(decoded, k);
    }

    // ================================================================
    // SIGNATURE: pack/unpack roundtrip
    // ================================================================

    function check_packSignature_roundtrip(bytes memory sig) public pure {
        vm.assume(sig.length > 0 && sig.length <= 100);
        bytes memory packed = Michelson.packSignature(sig);
        bytes memory decoded = Michelson.unpackSignature(packed);
        assertEq(decoded, sig);
    }

    // ================================================================
    // CHAIN_ID: pack/unpack roundtrip
    // ================================================================

    function check_packChainId_roundtrip(bytes memory cid) public pure {
        vm.assume(cid.length > 0 && cid.length <= 100);
        bytes memory packed = Michelson.packChainId(cid);
        bytes memory decoded = Michelson.unpackChainId(packed);
        assertEq(decoded, cid);
    }
}
