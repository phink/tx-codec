// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MichelsonSpec.sol";
import "../src/Michelson.sol";

/// @notice Demo contract deployed on-chain to exercise the PACK codec.
contract MichelsonDemo {
    event Packed(string typ, bytes packed);
    event Unpacked(string typ, string value);
    event GasUsed(string operation, uint256 gas);

    /// @notice Encode a nat, decode it back, verify roundtrip.
    function demoNat(uint256 n) external returns (bytes memory packed, uint256 decoded) {
        packed = MichelsonSpec.pack(MichelsonSpec.nat(n));
        decoded = MichelsonSpec.toNat(MichelsonSpec.unpack(packed));
        require(decoded == n, "nat roundtrip failed");
        emit Packed("nat", packed);
    }

    /// @notice Same with assembly decoder -- compare gas.
    function demoNatAsm(uint256 n) external returns (bytes memory packed, uint256 decoded) {
        packed = MichelsonSpec.pack(MichelsonSpec.nat(n));
        decoded = Michelson.unpackNat(packed);
        require(decoded == n, "nat asm roundtrip failed");
        emit Packed("nat_asm", packed);
    }

    /// @notice Encode a signed int, decode it back.
    function demoInt(int256 v) external returns (bytes memory packed, int256 decoded) {
        packed = MichelsonSpec.pack(MichelsonSpec.int_(v));
        decoded = MichelsonSpec.toInt(MichelsonSpec.unpack(packed));
        require(decoded == v, "int roundtrip failed");
        emit Packed("int", packed);
    }

    /// @notice Bool roundtrip.
    function demoBool(bool v) external returns (bytes memory packed, bool decoded) {
        packed = MichelsonSpec.pack(MichelsonSpec.bool_(v));
        decoded = MichelsonSpec.toBool(MichelsonSpec.unpack(packed));
        require(decoded == v, "bool roundtrip failed");
        emit Packed("bool", packed);
    }

    /// @notice String roundtrip.
    function demoString(string calldata s) external returns (bytes memory packed, string memory decoded) {
        packed = MichelsonSpec.pack(MichelsonSpec.string_(s));
        decoded = MichelsonSpec.toString(MichelsonSpec.unpack(packed));
        require(keccak256(bytes(decoded)) == keccak256(bytes(s)), "string roundtrip failed");
        emit Packed("string", packed);
    }

    /// @notice Mutez roundtrip.
    function demoMutez(uint64 v) external returns (bytes memory packed, uint64 decoded) {
        packed = MichelsonSpec.pack(MichelsonSpec.nat(uint256(v)));
        decoded = MichelsonSpec.toMutez(MichelsonSpec.unpack(packed));
        require(decoded == v, "mutez roundtrip failed");
        emit Packed("mutez", packed);
    }

    /// @notice Timestamp roundtrip.
    function demoTimestamp(int64 v) external returns (bytes memory packed, int64 decoded) {
        packed = MichelsonSpec.pack(MichelsonSpec.int_(int256(v)));
        decoded = MichelsonSpec.toTimestamp(MichelsonSpec.unpack(packed));
        require(decoded == v, "timestamp roundtrip failed");
        emit Packed("timestamp", packed);
    }

    /// @notice Composite example: pack a pair of nat and string.
    function demoPair(uint256 n, string calldata s) external returns (bytes memory packed) {
        packed = MichelsonSpec.pack(MichelsonSpec.pair(MichelsonSpec.nat(n), MichelsonSpec.string_(s)));
        emit Packed("pair", packed);
    }
}

contract DeployDemo is Script {
    function run() external {
        vm.startBroadcast();
        MichelsonDemo demo = new MichelsonDemo();
        console.log("Demo deployed at:", address(demo));
        vm.stopBroadcast();
    }
}
