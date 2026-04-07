# MichelinePack -- Michelson PACK Codec for Solidity

Solidity library for encoding/decoding Michelson `PACK` binary format on [Tezos X](https://tezos.com/).
Use it to make cross-runtime calls between EVM contracts and Michelson smart contracts.

## Quick start

```bash
# Build the Lean project (spec + transpiler)
lake build

# Emit the Solidity library from the verified spec
lake exe michelinepack emit > sol-test/src/MichelsonSpec.sol

# Run Solidity tests (330 fuzz + 96 asm-diff + 414 octez-client checks)
cd sol-test && forge test

# CLI encode/decode
lake exe michelinepack encode 42      # -> 05002a
lake exe michelinepack decode 05002a  # -> 42
```

**Deployed demo:** `0x903632fC76B67910A663d243eefe70Cb54e96fa2` on Etherlink.

## Type correspondence

| Michelson type | Solidity encode | Solidity decode | EVM type | Lean roundtrip |
|---|---|---|---|---|
| `nat` | `Michelson.nat(n)` | `Michelson.toNat(data)` | `uint256` | Both (left + right) |
| `int` | `Michelson.int_(v)` | `Michelson.toInt(data)` | `int256` | Both |
| `bool` | `Michelson.bool_(b)` | `Michelson.toBool(data)` | `bool` | Both |
| `unit` | `Michelson.unit_()` | `Michelson.toUnit(data)` | *(none)* | Both |
| `string` | `Michelson.string_(s)` | `Michelson.toString(data)` | `string` | Both |
| `bytes` | `Michelson.bytes_(d)` | `Michelson.toBytes(data)` | `bytes` | Both |
| `mutez` | `Michelson.nat(uint256(v))` | `Michelson.toMutez(data)` | `uint64` | Both |
| `timestamp` | `Michelson.int_(int256(v))` | `Michelson.toTimestamp(data)` | `int64` | Both |
| `pair` | `Michelson.pair(a, b)` | `Michelson.toPair(data)` | `(bytes, bytes)` | Both |
| `or` | `Michelson.left(a)` / `right(b)` | `Michelson.toOr(data)` | `(bool, bytes)` | Both |
| `option` | `Michelson.some(a)` / `none()` | `Michelson.toOption(data)` | `(bool, bytes)` | Both |
| `list` | `Michelson.list(items)` | `Michelson.toList(data)` | `bytes[]` | Both |
| `map` | `Michelson.map(elts)` | `Michelson.toMap(data)` | `bytes[]` | Both |
| `set` | `Michelson.set(items)` | `Michelson.toSet(data)` | `bytes[]` | Both |
| `address` | `Michelson.address_(addr)` | `Michelson.toAddress(data)` | `bytes` (22B raw) | Both |
| `key_hash` | `Michelson.keyHash(kh)` | `Michelson.toKeyHash(data)` | `bytes` (21B raw) | Both |
| `key` | `Michelson.key(k)` | `Michelson.toKey(data)` | `bytes` (raw) | Both |
| `signature` | `Michelson.signature_(s)` | `Michelson.toSignature(data)` | `bytes` (raw) | Both |
| `chain_id` | `Michelson.chainId(id)` | `Michelson.toChainId(data)` | `bytes4` | Both |
| `contract` | `Michelson.contract_(addr, ep)` | `Michelson.toContract(data)` | `(bytes, bytes)` | Left |

## API usage examples

```solidity
// Pack a nat
bytes memory packed = Michelson.pack(Michelson.nat(42));

// Unpack a nat
uint256 value = Michelson.toNat(Michelson.unpack(packed));

// Pack a pair of nat and string
bytes memory pairPacked = Michelson.pack(
    Michelson.pair(Michelson.nat(42), Michelson.string_("hello"))
);

// Pack an or (Left nat)
bytes memory orPacked = Michelson.pack(Michelson.left(Michelson.nat(1)));

// Pack an option (Some bool)
bytes memory optPacked = Michelson.pack(Michelson.some(Michelson.bool_(true)));

// Pack None
bytes memory nonePacked = Michelson.pack(Michelson.none());

// Binary types: raw bytes, NOT base58check
bytes memory addrPacked = Michelson.pack(Michelson.address_(rawAddrBytes));
```

**Two-level API.** `Michelson.nat(42)` builds inner Micheline (no `0x05` prefix) --
composable inside pairs, lists, etc. `Michelson.pack(...)` adds the `0x05` prefix
for top-level PACK format. Never nest `pack` inside a composite:
`pair(pack(nat(1)), pack(nat(2)))` is **wrong**. Correct: `pack(pair(nat(1), nat(2)))`.

**Binary types** (address, key, key_hash, signature) take **raw binary bytes**,
not base58check strings. The caller must convert.

## Overflow behavior

| Condition | Error |
|-----------|-------|
| nat > 2^256-1 | `IntOverflow()` revert |
| int outside +/-2^255 | `IntOverflow()` revert |
| mutez >= 2^63 | `IntOverflow()` revert |
| timestamp outside +/-2^63 | `IntOverflow()` revert |
| Truncated input | `InputTruncated()` revert |
| Wrong node tag | `UnexpectedNodeTag(expected, got)` revert |
| Sign bit in nat | `NatNegative()` revert |
| Non-canonical encoding | `TrailingZeroByte()` or `NegativeZero()` revert |

## Gas benchmarks

The library ships two Solidity implementations: `MichelsonSpec.sol` (reference,
transpiler-generated) and `Michelson.sol` (production, assembly-optimized).
Assembly saves 79-99% gas on atom operations:

| Operation | Spec (gas) | Asm (gas) | Savings |
|---|---|---|---|
| packNat(0) | 793 | 116 | 85% |
| packNat(uint256.max) | 17,961 | 3,316 | 82% |
| packInt(int256.min) | 17,950 | 3,310 | 82% |
| packBool(true) | 470 | 77 | 84% |
| packString("hello") | 801 | 563 | 30% |
| packUnit | 470 | 80 | 83% |
| unpackNat(42) | 1,546 | 263 | 83% |
| unpackNat(uint256.max) | 32,349 | 6,726 | 79% |
| unpackInt(-42) | 1,525 | 324 | 79% |
| unpackInt(int256.min) | 32,330 | 6,781 | 79% |
| unpackBool | 1,432 | 217 | 85% |
| unpackString(256B) | 135,881 | 1,048 | 99% |
| unpackUnit | 1,448 | 155 | 89% |
| unpackMutez(max) | 9,288 | 2,059 | 78% |
| unpackTimestamp | 3,325 | 906 | 73% |

Composite types (pair, or, option, list, map) delegate to the spec — assembly
savings come from the inner atom operations.

**Run the benchmark yourself:**
```bash
cd sol-test && forge test --match-contract GasBenchmark -vvv 2>&1 | grep -E "spec|asm"
```

The benchmark code is in `sol-test/test/GasBenchmark.t.sol`. Each test measures
both the spec and assembly implementations using `gasleft()` differentials,
then emits the results as named logs.

## File structure

| File | Purpose |
|------|---------|
| `MichelinePack/Micheline.lean` | Pure spec: encode/decode over `List (Fin 256)`, roundtrip proofs, zero sorry |
| `MichelinePack/Implementation.lean` | Offset-based Solidity-shaped functions, 63 equivalence theorems to spec |
| `MichelinePack/Transpile.lean` | SolStmt IR transpiler, emits all 52 Solidity functions |
| `sol-test/src/Michelson.sol` | Production Solidity library (assembly-optimized) |
| `sol-test/src/MichelsonSpec.sol` | Reference Solidity library (transpiler-generated) |
| `sol-test/src/MichelsonDemo.sol` | Demo contract for deployment |
| `technical_report/report.tex` | 22-page technical report (architecture, proofs, gas benchmarks) |

## Verification

The library is formally verified at two levels.

**Lean 4 proofs (49 theorems, zero sorry, zero axioms).** Both left and right
roundtrips proven for all 20 types:
- Left: `decode(encode(x)) = x` -- no information loss
- Right: `encode(decode(bs)) = bs` -- encoding is canonical (unique)

Plus 63 equivalence theorems proving the offset-based implementation matches
the pure spec. All byte lists use `List (Fin 256)` -- byte validity is structural.

**Halmos symbolic proofs (40 checks).** Proves properties over *all* inputs on the
compiled EVM bytecode: 18 asm-vs-spec equivalence, 12 spec roundtrips, 6 binary
roundtrips, 4 adversarial checks (arbitrary bytes: asm rejects iff spec rejects).

**Foundry + octez-client (840 checks).** 330 fuzz tests, 96 asm-differential checks,
414 octez-client compatibility tests against the reference Michelson implementation.

### Dependencies

- Lean 4 v4.29.0 (no Mathlib)
- Foundry (`forge test`)
- Halmos (optional, `sol-test/.venv/`)
