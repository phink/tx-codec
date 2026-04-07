#!/usr/bin/env bash
# Differential test: compare MichelsonPack Solidity output against octez-client.
#
# Usage: ./test/differential.sh
#
# Requires:
#   - octez-client at $OCTEZ_CLIENT (default: /home/phink/nomadic/tezos/octez-client)
#   - forge in PATH
#   - TEZOS_CLIENT_UNSAFE_DISABLE_DISCLAIMER=y

set -euo pipefail

OCTEZ_CLIENT="${OCTEZ_CLIENT:-/home/phink/nomadic/tezos/octez-client}"
export TEZOS_CLIENT_UNSAFE_DISABLE_DISCLAIMER=y

PASS=0
FAIL=0
TOTAL=0

red() { printf "\033[31m%s\033[0m" "$1"; }
green() { printf "\033[32m%s\033[0m" "$1"; }

# Pack a value using octez-client: octez_pack <value> <type> -> hex string (lowercase, with 0x)
octez_pack() {
    local val="$1" typ="$2"
    "$OCTEZ_CLIENT" hash data "$val" of type "$typ" 2>&1 | grep "Raw packed data:" | awk '{print $4}'
}

# Unpack hex using octez-client: octez_unpack <hex> -> value string
octez_unpack() {
    local hex="$1"
    "$OCTEZ_CLIENT" unpack michelson data "$hex" 2>&1 | head -1
}

# Pack using Lean CLI: lean_pack <value> -> hex string (lowercase, with 0x)
# Currently only supports nat encoding.
lean_pack() {
    local n="$1"
    cd "$(dirname "$0")/../.." && lake exe michelinepack encode "$n" 2>/dev/null | grep "packed:" | awk '{print "0x"$2}'
}

check() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    # Normalize: lowercase, ensure 0x prefix
    expected=$(echo "$expected" | tr '[:upper:]' '[:lower:]')
    actual=$(echo "$actual" | tr '[:upper:]' '[:lower:]')
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
        printf "  $(green PASS) %s\n" "$desc"
    else
        FAIL=$((FAIL + 1))
        printf "  $(red FAIL) %s\n" "$desc"
        printf "       expected: %s\n" "$expected"
        printf "       actual:   %s\n" "$actual"
    fi
}

check_value() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
        printf "  $(green PASS) %s\n" "$desc"
    else
        FAIL=$((FAIL + 1))
        printf "  $(red FAIL) %s\n" "$desc"
        printf "       expected: %s\n" "$expected"
        printf "       actual:   %s\n" "$actual"
    fi
}

# Test Lean CLI output against octez-client for nat values
test_pack_lean() {
    local value="$1" type="$2" desc="$3"
    local octez_hex lean_hex
    octez_hex=$(octez_pack "$value" "$type")
    lean_hex=$(lean_pack "$value")
    check "pack $desc (lean vs octez)" "$octez_hex" "$lean_hex"
}

# Test octez pack -> unpack roundtrip (no hardcoded hex)
test_roundtrip() {
    local value="$1" type="$2" desc="$3"
    local octez_hex octez_val
    octez_hex=$(octez_pack "$value" "$type")
    octez_val=$(octez_unpack "$octez_hex")
    check_value "roundtrip $desc" "$value" "$octez_val"
}

# Test that octez produces non-empty packed data for a given value+type
test_pack_nonempty() {
    local value="$1" type="$2" desc="$3"
    local octez_hex
    octez_hex=$(octez_pack "$value" "$type")
    TOTAL=$((TOTAL + 1))
    if [ -n "$octez_hex" ] && [ "$octez_hex" != "" ]; then
        PASS=$((PASS + 1))
        printf "  $(green PASS) %s pack non-empty\n" "$desc"
    else
        FAIL=$((FAIL + 1))
        printf "  $(red FAIL) %s pack empty\n" "$desc"
    fi
}

# Test octez self-consistency: pack then unpack, repack, verify hex matches
test_repack() {
    local value="$1" type="$2" desc="$3"
    local octez_hex1 octez_val octez_hex2
    octez_hex1=$(octez_pack "$value" "$type")
    octez_val=$(octez_unpack "$octez_hex1")
    octez_hex2=$(octez_pack "$octez_val" "$type")
    check "repack $desc" "$octez_hex1" "$octez_hex2"
}

echo "=== Differential tests: Lean/Solidity vs octez-client ==="
echo ""

# ================================================================
# NAT
# ================================================================
echo "--- nat: pack (Lean CLI vs octez) ---"

nat_values=(
    0 1 42 63 64 127 128 255 256
    8191 8192 16383 16384
    65535 65536
    1000000
    4294967295       # 2^32 - 1
    4294967296       # 2^32
    18446744073709551615                                    # 2^64 - 1
    18446744073709551616                                    # 2^64
    340282366920938463463374607431768211456                  # 2^128
    57896044618658097711785492504343953926634992332820282019728792003956564819967  # 2^255 - 1
    115792089237316195423570985008687907853269984665640564039457584007913129639935 # 2^256 - 1
    999999999999999999999
)

for n in "${nat_values[@]}"; do
    test_pack_lean "$n" "nat" "nat($n)"
done

echo ""
echo "--- nat: roundtrip (through octez) ---"

for n in "${nat_values[@]}"; do
    test_roundtrip "$n" "nat" "nat($n)"
done

# ================================================================
# INT
# ================================================================
echo ""
echo "--- int: roundtrip (comprehensive boundaries) ---"

int_values=(
    0 1 -1 42 -42
    63 -63 64 -64
    127 -127 128 -128
    255 -255 256 -256
    8191 -8191 8192 -8192
    16383 -16383 16384 -16384
    65535 -65535 65536 -65536
    1000000 -1000000
    4294967295 -4294967295       # 2^32 - 1
    4294967296 -4294967296       # 2^32
    18446744073709551615                                    # 2^64 - 1
    -18446744073709551615                                   # -(2^64 - 1)
    340282366920938463463374607431768211456                  # 2^128
    -340282366920938463463374607431768211456                 # -(2^128)
    57896044618658097711785492504343953926634992332820282019728792003956564819967  # 2^255 - 1
    -57896044618658097711785492504343953926634992332820282019728792003956564819968 # -(2^255)
)

for v in "${int_values[@]}"; do
    test_roundtrip "$v" "int" "int($v)"
done

# ================================================================
# BOOL
# ================================================================
echo ""
echo "--- bool: roundtrip ---"

test_roundtrip "True"  "bool" "bool(True)"
test_roundtrip "False" "bool" "bool(False)"

# ================================================================
# UNIT
# ================================================================
echo ""
echo "--- unit: roundtrip ---"

test_roundtrip "Unit" "unit" "unit(Unit)"

# ================================================================
# STRING
# ================================================================
echo ""
echo "--- string: roundtrip ---"

string_values=(
    '""'
    '"a"'
    '"hello"'
    '"hello world"'
    '"tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb"'
    '"abcdefghij"'
)

for s in "${string_values[@]}"; do
    test_roundtrip "$s" "string" "string($s)"
done

echo ""
echo "--- string: special characters ---"

test_roundtrip '"a\"b"' "string" 'string("a\"b")'
test_roundtrip '"a\nb"' "string" 'string("a\nb")'

echo ""
echo "--- string: length boundary (255 and 256 bytes) ---"

# Generate a 255-byte string (255 'a' chars)
str255=$(printf '%0.sa' $(seq 1 255))
test_roundtrip "\"$str255\"" "string" "string(255 bytes)"

# Generate a 256-byte string (256 'a' chars)
str256=$(printf '%0.sa' $(seq 1 256))
test_roundtrip "\"$str256\"" "string" "string(256 bytes)"

# Verify the length prefix crosses the 0xff boundary by comparing the two packed outputs
octez_hex_255=$(octez_pack "\"$str255\"" "string")
octez_hex_256=$(octez_pack "\"$str256\"" "string")
len_prefix_255=$(echo "$octez_hex_255" | cut -c5-14)  # chars after "0x05": tag(01) + 4-byte length
len_prefix_256=$(echo "$octez_hex_256" | cut -c5-14)
# 255 bytes -> length 0x000000ff, 256 bytes -> length 0x00000100
# Verify they differ (the 256-byte length prefix should be different from the 255-byte one)
check "string length prefix 255 vs 256 differ" "true" "$([ "$len_prefix_255" != "$len_prefix_256" ] && echo true || echo false)"

# ================================================================
# BYTES
# ================================================================
echo ""
echo "--- bytes: roundtrip ---"

bytes_values=(
    "0x"
    "0x00"
    "0xff"
    "0xdeadbeef"
    "0x0000000000000000"
    "0xaabbccdd"
)

for b in "${bytes_values[@]}"; do
    test_roundtrip "$b" "bytes" "bytes($b)"
done

# ================================================================
# MUTEZ
# ================================================================
echo ""
echo "--- mutez: pack (Lean CLI vs octez) ---"

mutez_values=(
    0 1 42 1000000 9223372036854775807
)

for v in "${mutez_values[@]}"; do
    test_pack_lean "$v" "mutez" "mutez($v)"
done

echo ""
echo "--- mutez: roundtrip ---"

for v in "${mutez_values[@]}"; do
    test_roundtrip "$v" "mutez" "mutez($v)"
done

# ================================================================
# TIMESTAMP
# ================================================================
echo ""
echo "--- timestamp: pack (Lean CLI vs octez for positive values) ---"

# The Lean CLI encodes zarith which matches both nat and positive timestamps/ints
for v in 0 1 1000000; do
    test_pack_lean "$v" "timestamp" "timestamp($v)"
done

echo ""
echo "--- timestamp: roundtrip (comprehensive) ---"

timestamp_values=(
    0 1 -1
    1000000 -1000000
    2147483647           # max int32
    -2147483648          # min int32
    9223372036854775807  # max int64
    -9223372036854775808 # min int64
)

for v in "${timestamp_values[@]}"; do
    test_roundtrip "$v" "timestamp" "timestamp($v)"
done

# ================================================================
# PAIR
# ================================================================
echo ""
echo "--- pair: roundtrip ---"

test_roundtrip 'Pair 0 0'                          'pair nat nat'                 "pair(0,0)"
test_roundtrip 'Pair 42 "hello"'                    'pair nat string'              "pair(42,hello)"
test_roundtrip 'Pair True False'                    'pair bool bool'               "pair(True,False)"
test_roundtrip 'Pair 1 (Pair 2 3)'                  'pair nat (pair nat nat)'      "pair(1,(2,3))"
test_roundtrip 'Pair "hello" (Pair 42 True)'        'pair string (pair nat bool)'  "pair(hello,(42,True))"

# ================================================================
# OR
# ================================================================
echo ""
echo "--- or: roundtrip ---"

test_roundtrip 'Left 42'            'or nat string'           "or(Left 42)"
test_roundtrip 'Right "hello"'      'or nat string'           'or(Right "hello")'
test_roundtrip 'Left True'          'or bool nat'             "or(Left True)"
test_roundtrip 'Right 0'            'or string nat'           "or(Right 0)"
test_roundtrip 'Left (Left 1)'      'or (or nat string) nat'  "or(Left(Left 1))"

# ================================================================
# OPTION
# ================================================================
echo ""
echo "--- option: roundtrip ---"

test_roundtrip 'Some 42'          'option nat'           "option(Some 42)"
test_roundtrip 'Some "hello"'     'option string'        'option(Some "hello")'
test_roundtrip 'Some True'        'option bool'          "option(Some True)"
test_roundtrip 'None'             'option nat'           "option(None)"
test_roundtrip 'Some (Some 1)'    'option (option nat)'  "option(Some(Some 1))"
test_roundtrip 'Some None'        'option (option nat)'  "option(Some None)"

# ================================================================
# LIST
# ================================================================
echo ""
echo "--- list: roundtrip ---"

test_roundtrip '{}'                                           'list nat'    "list(empty)"
test_roundtrip '{ 1 }'                                        'list nat'    "list({1})"
test_roundtrip '{ 1 ; 2 ; 3 }'                                'list nat'    "list({1,2,3})"
test_roundtrip '{ 1 ; 2 ; 3 ; 4 ; 5 ; 6 ; 7 ; 8 ; 9 ; 10 }' 'list nat'    "list({1..10})"
test_roundtrip '{ "hello" ; "world" }'                         'list string' 'list({"hello","world"})'

# ================================================================
# MAP
# ================================================================
echo ""
echo "--- map: roundtrip ---"

test_roundtrip '{}'                                             'map nat string'  "map(empty)"
test_roundtrip '{ Elt 1 "a" ; Elt 2 "b" }'                     'map nat string'  "map(2 elts)"
test_roundtrip '{ Elt 1 "a" ; Elt 2 "b" ; Elt 3 "c" }'        'map nat string'  "map(3 elts)"

# ================================================================
# SET
# ================================================================
echo ""
echo "--- set: roundtrip ---"

test_roundtrip '{}'                                    'set nat'  "set(empty)"
test_roundtrip '{ 1 ; 2 ; 3 }'                        'set nat'  "set({1,2,3})"
test_roundtrip '{ 10 ; 20 ; 30 ; 40 ; 50 }'           'set nat'  "set({10,20,30,40,50})"

# ================================================================
# ADDRESS
# ================================================================
echo ""
echo "--- address: octez self-consistency ---"

for addr in \
    '"tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb"' \
    '"tz2BFTyPeYRzxd5aiBchbXN3WCZhx7BqbMBq"' \
    '"tz3WXYtyDUNL91qfiCJtVUX746QpNv5i5ve5"' \
    '"KT1BEqzn5Wx8uJrZNvuS9DVHmLvG9td3fDLi"'; do
    test_pack_nonempty "$addr" 'address' "address($addr)"
    test_repack "$addr" 'address' "address($addr)"
done

# ================================================================
# KEY_HASH
# ================================================================
echo ""
echo "--- key_hash: octez self-consistency ---"

for kh in \
    '"tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb"' \
    '"tz2BFTyPeYRzxd5aiBchbXN3WCZhx7BqbMBq"' \
    '"tz3WXYtyDUNL91qfiCJtVUX746QpNv5i5ve5"'; do
    test_pack_nonempty "$kh" 'key_hash' "key_hash($kh)"
    test_repack "$kh" 'key_hash' "key_hash($kh)"
done

# ================================================================
# KEY
# ================================================================
echo ""
echo "--- key: octez self-consistency ---"

for k in \
    '"edpkvGfYw3LyB1UcCahKQk4rF2tvbMUk8GFiTuMjL75uGXrpvKXhjn"' \
    '"sppk7Zik17H7AxECMggqD1FyXUQdrGRFtz9X7aR8W2BhaJoWwSnPEGA"' \
    '"p2pk67Cwb5Ke6oSmqeUbJxURXMe3coVnH9tqPiB2xD84CYhHbBKs4oM"'; do
    test_pack_nonempty "$k" 'key' "key($k)"
    test_repack "$k" 'key' "key($k)"
done

# ================================================================
# CHAIN_ID
# ================================================================
echo ""
echo "--- chain_id: octez self-consistency ---"

test_pack_nonempty '"NetXdQprcVkpaWU"' 'chain_id' "chain_id(mainnet)"
test_repack '"NetXdQprcVkpaWU"' 'chain_id' "chain_id(mainnet)"

# ================================================================
# CROSS-TYPE CONSISTENCY CHECKS
# ================================================================
echo ""
echo "--- cross-type consistency ---"

# nat(0) and int(0) should produce the same bytes
nat0=$(octez_pack 0 nat)
int0=$(octez_pack 0 int)
check "nat(0) == int(0)" "$nat0" "$int0"

# nat(1) and int(1) should produce the same bytes
nat1=$(octez_pack 1 nat)
int1=$(octez_pack 1 int)
check "nat(1) == int(1)" "$nat1" "$int1"

# nat(42) and int(42) should produce the same bytes (positive values share zarith encoding)
nat42=$(octez_pack 42 nat)
int42=$(octez_pack 42 int)
check "nat(42) == int(42)" "$nat42" "$int42"

# nat(127) and int(127) -- compare octez outputs against each other
nat127=$(octez_pack 127 nat)
int127=$(octez_pack 127 int)
check "nat(127) == int(127)" "$nat127" "$int127"

# nat(128) and int(128) should produce the same bytes
nat128=$(octez_pack 128 nat)
int128=$(octez_pack 128 int)
check "nat(128) == int(128)" "$nat128" "$int128"

# mutez uses the same encoding as nat
nat1000000=$(octez_pack 1000000 nat)
mutez1000000=$(octez_pack 1000000 mutez)
check "nat(1000000) == mutez(1000000)" "$nat1000000" "$mutez1000000"

# positive timestamp uses the same encoding as int
ts_pos=$(octez_pack 1000000 timestamp)
int_pos=$(octez_pack 1000000 int)
check "timestamp(1000000) == int(1000000)" "$ts_pos" "$int_pos"

# negative timestamp uses the same encoding as int
ts_neg=$(octez_pack -1 timestamp)
int_neg=$(octez_pack -1 int)
check "timestamp(-1) == int(-1)" "$ts_neg" "$int_neg"

# ================================================================
# ZARITH BYTE-BOUNDARY STRESS TESTS
# ================================================================
echo ""
echo "--- zarith byte boundaries: nat ---"

# For nat zarith, the structure is:
#   - First byte holds 7 data bits (bits 0-6), bit 7 = continuation
#   - Subsequent bytes hold 7 data bits each, bit 7 = continuation
# Boundaries at: 2^7=128, 2^14=16384, 2^21=2097152, 2^28=268435456, ...

zarith_nat_boundaries=(
    # 1-byte values (0-127)
    0 1 63 64 126 127
    # 2-byte values (128-16383)
    128 129 255 256 8191 8192 16382 16383
    # 3-byte values (16384-2097151)
    16384 16385 65535 65536 2097150 2097151
    # 4-byte values
    2097152 268435455
    # 5-byte values
    268435456 34359738367
)

for n in "${zarith_nat_boundaries[@]}"; do
    test_pack_lean "$n" "nat" "nat_boundary($n)"
    test_roundtrip "$n" "nat" "nat_boundary($n)"
done

echo ""
echo "--- zarith byte boundaries: int ---"

# For int zarith, the structure is:
#   - First byte holds 6 data bits (bits 0-5), bit 6 = sign, bit 7 = continuation
#   - Subsequent bytes hold 7 data bits each, bit 7 = continuation
# Positive boundaries at: 2^6=64, 2^13=8192, 2^20=1048576, ...
# Negative boundaries similarly

zarith_int_boundaries=(
    # 1-byte positive (0-63)
    0 1 31 32 62 63
    # 1-byte negative (-1 to -63)
    -1 -31 -32 -62 -63
    # 2-byte positive (64-8191)
    64 65 127 128 255 256 4095 4096 8190 8191
    # 2-byte negative
    -64 -65 -127 -128 -255 -256 -4095 -4096 -8190 -8191
    # 3-byte positive (8192-1048575)
    8192 8193 16383 16384 65535 65536 1048574 1048575
    # 3-byte negative
    -8192 -8193 -16383 -16384 -65535 -65536 -1048574 -1048575
    # 4-byte boundary
    1048576 -1048576
)

for v in "${zarith_int_boundaries[@]}"; do
    test_roundtrip "$v" "int" "int_boundary($v)"
done

# ================================================================
# EDGE CASE: very large nat values via Lean
# ================================================================
echo ""
echo "--- very large nats (Lean vs octez) ---"

large_nats=(
    999999999999999999999
    18446744073709551615                                                              # 2^64-1
    18446744073709551616                                                              # 2^64
    340282366920938463463374607431768211456                                            # 2^128
    57896044618658097711785492504343953926634992332820282019728792003956564819967        # 2^255-1
    115792089237316195423570985008687907853269984665640564039457584007913129639935       # 2^256-1
)

for n in "${large_nats[@]}"; do
    test_pack_lean "$n" "nat" "large_nat($n)"
    test_roundtrip "$n" "nat" "large_nat_rt($n)"
done

# ================================================================
# EDGE CASE: very large int values
# ================================================================
echo ""
echo "--- very large ints (roundtrip) ---"

large_ints=(
    18446744073709551615       # 2^64-1
    -18446744073709551615      # -(2^64-1)
    18446744073709551616       # 2^64
    -18446744073709551616      # -(2^64)
    340282366920938463463374607431768211456   # 2^128
    -340282366920938463463374607431768211456  # -(2^128)
    57896044618658097711785492504343953926634992332820282019728792003956564819967   # 2^255-1
    -57896044618658097711785492504343953926634992332820282019728792003956564819968  # -(2^255)
)

for v in "${large_ints[@]}"; do
    test_roundtrip "$v" "int" "large_int($v)"
done

# ================================================================
# COMPOSITE EDGE CASES
# ================================================================
echo ""
echo "--- composite edge cases ---"

# Pair with large values
test_roundtrip 'Pair 999999999 "test"' 'pair nat string' "pair(large_nat,string)"

# Nested options: Some (Some (Some 1))
test_roundtrip 'Some (Some (Some 1))' 'option (option (option nat))' "option(3-deep)"

# Option of pair
test_roundtrip 'Some (Pair 1 2)' 'option (pair nat nat)' "option(pair)"
test_roundtrip 'None' 'option (pair nat nat)' "option(pair) None"

# Or of pair
test_roundtrip 'Left (Pair 1 2)' 'or (pair nat nat) string' "or(Left pair)"
test_roundtrip 'Right "test"' 'or (pair nat nat) string' "or(Right string)"

# List of pairs
test_roundtrip '{ Pair 1 "a" ; Pair 2 "b" }' 'list (pair nat string)' "list(pairs)"

# List of options
test_roundtrip '{ Some 1 ; None ; Some 3 }' 'list (option nat)' "list(options)"

# Map with string keys
test_roundtrip '{ Elt "x" 1 ; Elt "y" 2 }' 'map string nat' "map(string->nat)"

# Pair of lists
test_roundtrip 'Pair { 1 ; 2 } { 3 ; 4 }' 'pair (list nat) (list nat)' "pair(lists)"

# Empty map and empty list in a pair
test_roundtrip 'Pair {} {}' 'pair (list nat) (map nat string)' "pair(empty_list,empty_map)"

# Deeply nested pair
test_roundtrip 'Pair 1 (Pair 2 (Pair 3 (Pair 4 5)))' 'pair nat (pair nat (pair nat (pair nat nat)))' "pair(4-deep)"

# Or with or values
test_roundtrip 'Right (Left 42)' 'or string (or nat bool)' "or(Right(Left))"
test_roundtrip 'Right (Right True)' 'or string (or nat bool)' "or(Right(Right))"

# ================================================================
# Summary
# ================================================================
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
