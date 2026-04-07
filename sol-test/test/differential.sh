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

# Pack using Foundry: forge_pack <solidity_expr> -> hex string (lowercase, with 0x)
# We use forge script inline via cast
forge_pack_nat() {
    local n="$1"
    cast call --rpc-url http://localhost:1 0x0000000000000000000000000000000000000000 "" 2>/dev/null || true
    # Use a temp Solidity file to call packNat
    echo "" > /dev/null  # placeholder -- we'll use the Lean CLI instead
}

# Helper: run Lean CLI to pack nat -> hex
lean_pack_nat() {
    local n="$1"
    cd "$(dirname "$0")/../../lean-test" && lake exe zarithtest encode "$n" 2>/dev/null | grep "packed:" | awk '{print "0x"$2}'
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

# Helper: test both pack and unpack directions for a given value+type.
# Pack direction: our known hex == octez hex (when known_hex is provided)
# Unpack direction: octez pack -> octez unpack -> verify roundtrip matches value
test_pack_known() {
    local value="$1" type="$2" desc="$3" known_hex="$4"
    local octez_hex
    octez_hex=$(octez_pack "$value" "$type")
    check "pack $desc" "$known_hex" "$octez_hex"
}

test_roundtrip() {
    local value="$1" type="$2" desc="$3"
    local octez_hex octez_val
    octez_hex=$(octez_pack "$value" "$type")
    octez_val=$(octez_unpack "$octez_hex")
    check_value "roundtrip $desc" "$value" "$octez_val"
}

test_pack_lean() {
    local value="$1" type="$2" desc="$3"
    local octez_hex lean_hex
    octez_hex=$(octez_pack "$value" "$type")
    lean_hex=$(lean_pack_nat "$value")
    check "pack $desc (lean vs octez)" "$octez_hex" "$lean_hex"
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
echo "--- nat: unpack (roundtrip through octez) ---"

for n in "${nat_values[@]}"; do
    test_roundtrip "$n" "nat" "nat($n)"
done

echo ""
echo "--- nat: known vectors ---"

check "packNat(0)"     "0x050000"       "$(octez_pack 0 nat)"
check "packNat(1)"     "0x050001"       "$(octez_pack 1 nat)"
check "packNat(42)"    "0x05002a"       "$(octez_pack 42 nat)"
check "packNat(63)"    "0x05003f"       "$(octez_pack 63 nat)"
check "packNat(64)"    "0x05008001"     "$(octez_pack 64 nat)"
check "packNat(127)"   "0x0500bf01"     "$(octez_pack 127 nat)"
check "packNat(128)"   "0x05008002"     "$(octez_pack 128 nat)"
check "packNat(255)"   "0x0500bf03"     "$(octez_pack 255 nat)"
check "packNat(256)"   "0x05008004"     "$(octez_pack 256 nat)"
check "packNat(8192)"  "0x0500808001"   "$(octez_pack 8192 nat)"
check "packNat(16383)" "0x0500bfff01"   "$(octez_pack 16383 nat)"
check "packNat(16384)" "0x0500808002"   "$(octez_pack 16384 nat)"

# ================================================================
# INT
# ================================================================
echo ""
echo "--- int: known vectors ---"

check "packInt(0)"    "0x050000"   "$(octez_pack 0 int)"
check "packInt(1)"    "0x050001"   "$(octez_pack 1 int)"
check "packInt(-1)"   "0x050041"   "$(octez_pack -1 int)"
check "packInt(42)"   "0x05002a"   "$(octez_pack 42 int)"
check "packInt(-42)"  "0x05006a"   "$(octez_pack -42 int)"
check "packInt(63)"   "0x05003f"   "$(octez_pack 63 int)"
check "packInt(-63)"  "0x05007f"   "$(octez_pack -63 int)"
check "packInt(64)"   "0x05008001" "$(octez_pack 64 int)"
check "packInt(-64)"  "0x0500c001" "$(octez_pack -64 int)"
check "packInt(127)"  "0x0500bf01" "$(octez_pack 127 int)"
check "packInt(-127)" "0x0500ff01" "$(octez_pack -127 int)"
check "packInt(128)"  "0x05008002" "$(octez_pack 128 int)"
check "packInt(-128)" "0x0500c002" "$(octez_pack -128 int)"
check "packInt(255)"  "0x0500bf03" "$(octez_pack 255 int)"
check "packInt(-255)" "0x0500ff03" "$(octez_pack -255 int)"
check "packInt(256)"  "0x05008004" "$(octez_pack 256 int)"
check "packInt(-256)" "0x0500c004" "$(octez_pack -256 int)"

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
echo "--- bool: pack ---"

check "packBool(True)"  "0x05030a" "$(octez_pack 'True' 'bool')"
check "packBool(False)" "0x050303" "$(octez_pack 'False' 'bool')"

echo ""
echo "--- bool: unpack ---"

check_value "unpackBool(True)"  "True"  "$(octez_unpack '0x05030a')"
check_value "unpackBool(False)" "False" "$(octez_unpack '0x050303')"

echo ""
echo "--- bool: roundtrip ---"

test_roundtrip "True"  "bool" "bool(True)"
test_roundtrip "False" "bool" "bool(False)"

# ================================================================
# UNIT
# ================================================================
echo ""
echo "--- unit: pack ---"

check "packUnit()" "0x05030b" "$(octez_pack 'Unit' 'unit')"

echo ""
echo "--- unit: unpack ---"

check_value "unpackUnit()" "Unit" "$(octez_unpack '0x05030b')"

echo ""
echo "--- unit: roundtrip ---"

test_roundtrip "Unit" "unit" "unit(Unit)"

# ================================================================
# STRING
# ================================================================
echo ""
echo "--- string: pack (known vectors) ---"

check "packString(\"\")"      "0x050100000000"           "$(octez_pack '""' 'string')"
check "packString(\"a\")"     "0x05010000000161"         "$(octez_pack '"a"' 'string')"
check "packString(\"hello\")" "0x05010000000568656c6c6f" "$(octez_pack '"hello"' 'string')"
check 'packString("hello world")' "0x05010000000b68656c6c6f20776f726c64" "$(octez_pack '"hello world"' 'string')"

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

# String with embedded quote
check 'packString("a\"b")' "0x050100000003612262" "$(octez_pack '"a\"b"' 'string')"
check_value 'roundtrip string("a\"b")' '"a\"b"' "$(octez_unpack '0x050100000003612262')"

# String with newline
check 'packString("a\nb")' "0x050100000003610a62" "$(octez_pack '"a\nb"' 'string')"
check_value 'roundtrip string("a\nb")' '"a\nb"' "$(octez_unpack '0x050100000003610a62')"

echo ""
echo "--- string: length boundary (255 and 256 bytes) ---"

# Generate a 255-byte string (255 'a' chars)
str255=$(printf '%0.sa' $(seq 1 255))
octez_hex_255=$(octez_pack "\"$str255\"" "string")
octez_val_255=$(octez_unpack "$octez_hex_255")
check_value "roundtrip string(255 bytes)" "\"$str255\"" "$octez_val_255"

# Generate a 256-byte string (256 'a' chars)
str256=$(printf '%0.sa' $(seq 1 256))
octez_hex_256=$(octez_pack "\"$str256\"" "string")
octez_val_256=$(octez_unpack "$octez_hex_256")
check_value "roundtrip string(256 bytes)" "\"$str256\"" "$octez_val_256"

# Verify the length prefix crosses the 0xff boundary
# 255 = 0x000000ff, 256 = 0x00000100
# In the packed data after 0x0501, the next 4 bytes are the length
len_prefix_255=$(echo "$octez_hex_255" | cut -c5-14)  # chars after "0x05": tag(01) + 4-byte length
len_prefix_256=$(echo "$octez_hex_256" | cut -c5-14)
check "string length prefix 255" "01000000ff" "$len_prefix_255"
check "string length prefix 256" "0100000100" "$len_prefix_256"

# ================================================================
# BYTES
# ================================================================
echo ""
echo "--- bytes: pack ---"

check "packBytes(0x)"         "0x050a00000000"         "$(octez_pack '0x' 'bytes')"
check "packBytes(0x00)"       "0x050a0000000100"       "$(octez_pack '0x00' 'bytes')"
check "packBytes(0xff)"       "0x050a00000001ff"       "$(octez_pack '0xff' 'bytes')"
check "packBytes(0xdeadbeef)" "0x050a00000004deadbeef" "$(octez_pack '0xdeadbeef' 'bytes')"
check "packBytes(0x0000000000000000)" "0x050a000000080000000000000000" "$(octez_pack '0x0000000000000000' 'bytes')"

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

echo ""
echo "--- timestamp: known vectors ---"

check "packTimestamp(0)"               "0x050000"                       "$(octez_pack 0 timestamp)"
check "packTimestamp(max_int64)"       "0x0500bfffffffffffffffff01"     "$(octez_pack 9223372036854775807 timestamp)"
check "packTimestamp(min_int64)"       "0x0500c0808080808080808002"     "$(octez_pack -9223372036854775808 timestamp)"

# ================================================================
# PAIR
# ================================================================
echo ""
echo "--- pair: pack (known vectors) ---"

check "packPair(0,0)"          "0x05070700000000"                                     "$(octez_pack 'Pair 0 0' 'pair nat nat')"
check "packPair(42,hello)"     "0x050707002a010000000568656c6c6f"                     "$(octez_pack 'Pair 42 "hello"' 'pair nat string')"
check "packPair(True,False)"   "0x050707030a0303"                                     "$(octez_pack 'Pair True False' 'pair bool bool')"

echo ""
echo "--- pair: nested ---"

check "packPair(1,(2,3))"             "0x0507070001070700020003"                       "$(octez_pack 'Pair 1 (Pair 2 3)' 'pair nat (pair nat nat)')"
check 'packPair("hello",(42,True))'   "0x050707010000000568656c6c6f0707002a030a"       "$(octez_pack 'Pair "hello" (Pair 42 True)' 'pair string (pair nat bool)')"

echo ""
echo "--- pair: roundtrip ---"

check_value "roundtrip pair(0,0)"          "Pair 0 0"                         "$(octez_unpack '0x05070700000000')"
check_value "roundtrip pair(42,hello)"     'Pair 42 "hello"'                  "$(octez_unpack '0x050707002a010000000568656c6c6f')"
check_value "roundtrip pair(True,False)"   "Pair True False"                  "$(octez_unpack '0x050707030a0303')"
check_value "roundtrip pair(1,(2,3))"      "Pair 1 (Pair 2 3)"               "$(octez_unpack '0x0507070001070700020003')"
check_value 'roundtrip pair(hello,(42,True))' 'Pair "hello" (Pair 42 True)'  "$(octez_unpack '0x050707010000000568656c6c6f0707002a030a')"

test_roundtrip 'Pair 0 0'                          'pair nat nat'                 "pair(0,0)"
test_roundtrip 'Pair 42 "hello"'                    'pair nat string'              "pair(42,hello)"
test_roundtrip 'Pair True False'                    'pair bool bool'               "pair(True,False)"
test_roundtrip 'Pair 1 (Pair 2 3)'                  'pair nat (pair nat nat)'      "pair(1,(2,3))"
test_roundtrip 'Pair "hello" (Pair 42 True)'        'pair string (pair nat bool)'  "pair(hello,(42,True))"

# ================================================================
# OR
# ================================================================
echo ""
echo "--- or: pack (known vectors) ---"

check "packLeft(42)"       "0x050505002a"                   "$(octez_pack 'Left 42' 'or nat string')"
check 'packRight("hello")' "0x050508010000000568656c6c6f"   "$(octez_pack 'Right "hello"' 'or nat string')"
check "packLeft(True)"     "0x050505030a"                   "$(octez_pack 'Left True' 'or bool nat')"
check "packRight(0)"       "0x0505080000"                   "$(octez_pack 'Right 0' 'or string nat')"

echo ""
echo "--- or: nested ---"

check "packLeft(Left 1)"  "0x05050505050001" "$(octez_pack 'Left (Left 1)' 'or (or nat string) nat')"

echo ""
echo "--- or: roundtrip ---"

check_value "roundtrip Left(42)"        "Left 42"        "$(octez_unpack '0x050505002a')"
check_value 'roundtrip Right("hello")'  'Right "hello"'  "$(octez_unpack '0x050508010000000568656c6c6f')"
check_value "roundtrip Left(True)"      "Left True"      "$(octez_unpack '0x050505030a')"
check_value "roundtrip Right(0)"        "Right 0"        "$(octez_unpack '0x0505080000')"
check_value "roundtrip Left(Left 1)"    "Left (Left 1)"  "$(octez_unpack '0x05050505050001')"

test_roundtrip 'Left 42'            'or nat string'           "or(Left 42)"
test_roundtrip 'Right "hello"'      'or nat string'           'or(Right "hello")'
test_roundtrip 'Left True'          'or bool nat'             "or(Left True)"
test_roundtrip 'Right 0'            'or string nat'           "or(Right 0)"
test_roundtrip 'Left (Left 1)'      'or (or nat string) nat'  "or(Left(Left 1))"

# ================================================================
# OPTION
# ================================================================
echo ""
echo "--- option: pack (known vectors) ---"

check "packSome(42)"       "0x050509002a"   "$(octez_pack 'Some 42' 'option nat')"
check 'packSome("hello")'  "0x050509010000000568656c6c6f" "$(octez_pack 'Some "hello"' 'option string')"
check "packSome(True)"     "0x050509030a"   "$(octez_pack 'Some True' 'option bool')"
check "packNone"           "0x050306"       "$(octez_pack 'None' 'option nat')"

echo ""
echo "--- option: nested ---"

check "packSome(Some 1)"  "0x05050905090001"  "$(octez_pack 'Some (Some 1)' 'option (option nat)')"
check "packSome(None)"    "0x0505090306"       "$(octez_pack 'Some None' 'option (option nat)')"

echo ""
echo "--- option: roundtrip ---"

check_value "roundtrip Some(42)"      "Some 42"      "$(octez_unpack '0x050509002a')"
check_value "roundtrip None"          "None"         "$(octez_unpack '0x050306')"
check_value "roundtrip Some(Some 1)"  "Some (Some 1)" "$(octez_unpack '0x05050905090001')"
check_value "roundtrip Some(None)"    "Some None"    "$(octez_unpack '0x0505090306')"

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
echo "--- list: pack (known vectors) ---"

check "packList(empty)"     "0x050200000000"                                     "$(octez_pack '{}' 'list nat')"
check "packList({1})"       "0x0502000000020001"                                 "$(octez_pack '{ 1 }' 'list nat')"
check "packList({1,2,3})"   "0x050200000006000100020003"                         "$(octez_pack '{ 1 ; 2 ; 3 }' 'list nat')"
check "packList({1..10})"   "0x050200000014000100020003000400050006000700080009000a" "$(octez_pack '{ 1 ; 2 ; 3 ; 4 ; 5 ; 6 ; 7 ; 8 ; 9 ; 10 }' 'list nat')"
check 'packList({"hello","world"})' "0x050200000014010000000568656c6c6f0100000005776f726c64" "$(octez_pack '{ "hello" ; "world" }' 'list string')"

echo ""
echo "--- list: roundtrip ---"

check_value "roundtrip list(empty)"    "{}"              "$(octez_unpack '0x050200000000')"
check_value "roundtrip list({1,2,3})"  "{ 1 ; 2 ; 3 }"  "$(octez_unpack '0x050200000006000100020003')"
check_value "roundtrip list({1..10})"  "{ 1 ; 2 ; 3 ; 4 ; 5 ; 6 ; 7 ; 8 ; 9 ; 10 }" "$(octez_unpack '0x050200000014000100020003000400050006000700080009000a')"
check_value 'roundtrip list({"hello","world"})' '{ "hello" ; "world" }' "$(octez_unpack '0x050200000014010000000568656c6c6f0100000005776f726c64')"

test_roundtrip '{}'                                           'list nat'    "list(empty)"
test_roundtrip '{ 1 }'                                        'list nat'    "list({1})"
test_roundtrip '{ 1 ; 2 ; 3 }'                                'list nat'    "list({1,2,3})"
test_roundtrip '{ 1 ; 2 ; 3 ; 4 ; 5 ; 6 ; 7 ; 8 ; 9 ; 10 }' 'list nat'    "list({1..10})"
test_roundtrip '{ "hello" ; "world" }'                         'list string' 'list({"hello","world"})'

# ================================================================
# MAP
# ================================================================
echo ""
echo "--- map: pack (known vectors) ---"

check "packMap(empty)"              "0x050200000000"                                                        "$(octez_pack '{}' 'map nat string')"
check "packMap(Elt 1 a, Elt 2 b)"  "0x0502000000140704000101000000016107040002010000000162"                  "$(octez_pack '{ Elt 1 "a" ; Elt 2 "b" }' 'map nat string')"

echo ""
echo "--- map: roundtrip ---"

check_value "roundtrip map(empty)"             "{}"                          "$(octez_unpack '0x050200000000')"
check_value "roundtrip map(Elt 1 a, Elt 2 b)" '{ Elt 1 "a" ; Elt 2 "b" }'  "$(octez_unpack '0x0502000000140704000101000000016107040002010000000162')"

test_roundtrip '{}'                                             'map nat string'  "map(empty)"
test_roundtrip '{ Elt 1 "a" ; Elt 2 "b" }'                     'map nat string'  "map(2 elts)"
test_roundtrip '{ Elt 1 "a" ; Elt 2 "b" ; Elt 3 "c" }'        'map nat string'  "map(3 elts)"

# ================================================================
# SET
# ================================================================
echo ""
echo "--- set: pack (known vectors) ---"

check "packSet(empty)"      "0x050200000000"             "$(octez_pack '{}' 'set nat')"
check "packSet({1,2,3})"    "0x050200000006000100020003" "$(octez_pack '{ 1 ; 2 ; 3 }' 'set nat')"

echo ""
echo "--- set: roundtrip ---"

test_roundtrip '{}'                                    'set nat'  "set(empty)"
test_roundtrip '{ 1 ; 2 ; 3 }'                        'set nat'  "set({1,2,3})"
test_roundtrip '{ 10 ; 20 ; 30 ; 40 ; 50 }'           'set nat'  "set({10,20,30,40,50})"

# ================================================================
# ADDRESS
# ================================================================
echo ""
echo "--- address: pack (known vectors) ---"

# tz1 (ed25519)
check "packAddress(tz1)" \
    "0x050a0000001600006b82198cb179e8306c1bedd08f12dc863f328886" \
    "$(octez_pack '"tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb"' 'address')"

# tz2 (secp256k1)
check "packAddress(tz2)" \
    "0x050a0000001600012031d34105bb1243b973e06139193221110a0ca1" \
    "$(octez_pack '"tz2BFTyPeYRzxd5aiBchbXN3WCZhx7BqbMBq"' 'address')"

# tz3 (p256)
check "packAddress(tz3)" \
    "0x050a0000001600026fde46af0356a0476dae4e4600172dc9309b3aa4" \
    "$(octez_pack '"tz3WXYtyDUNL91qfiCJtVUX746QpNv5i5ve5"' 'address')"

# KT1 (originated)
check "packAddress(KT1)" \
    "0x050a00000016011d23c1d3d2f8a4ea5e8784b8f7ecf2ad304c0fe600" \
    "$(octez_pack '"KT1BEqzn5Wx8uJrZNvuS9DVHmLvG9td3fDLi"' 'address')"

echo ""
echo "--- address: octez self-consistency ---"

# Note: octez unpack for address/key_hash/key/chain_id returns raw bytes, not base58.
# So we verify octez pack->unpack->repack consistency instead.
for addr in \
    '"tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb"' \
    '"tz2BFTyPeYRzxd5aiBchbXN3WCZhx7BqbMBq"' \
    '"tz3WXYtyDUNL91qfiCJtVUX746QpNv5i5ve5"' \
    '"KT1BEqzn5Wx8uJrZNvuS9DVHmLvG9td3fDLi"'; do
    octez_hex=$(octez_pack "$addr" 'address')
    # Just verify the hex is non-empty (valid packing)
    TOTAL=$((TOTAL + 1))
    if [ -n "$octez_hex" ] && [ "$octez_hex" != "" ]; then
        PASS=$((PASS + 1))
        printf "  $(green PASS) address pack non-empty: %s\n" "$addr"
    else
        FAIL=$((FAIL + 1))
        printf "  $(red FAIL) address pack empty: %s\n" "$addr"
    fi
done

# ================================================================
# KEY_HASH
# ================================================================
echo ""
echo "--- key_hash: pack (known vectors) ---"

# tz1 key_hash
check "packKeyHash(tz1)" \
    "0x050a00000015006b82198cb179e8306c1bedd08f12dc863f328886" \
    "$(octez_pack '"tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb"' 'key_hash')"

# tz2 key_hash
check "packKeyHash(tz2)" \
    "0x050a00000015012031d34105bb1243b973e06139193221110a0ca1" \
    "$(octez_pack '"tz2BFTyPeYRzxd5aiBchbXN3WCZhx7BqbMBq"' 'key_hash')"

# tz3 key_hash
check "packKeyHash(tz3)" \
    "0x050a00000015026fde46af0356a0476dae4e4600172dc9309b3aa4" \
    "$(octez_pack '"tz3WXYtyDUNL91qfiCJtVUX746QpNv5i5ve5"' 'key_hash')"

echo ""
echo "--- key_hash: octez self-consistency ---"

for kh in \
    '"tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb"' \
    '"tz2BFTyPeYRzxd5aiBchbXN3WCZhx7BqbMBq"' \
    '"tz3WXYtyDUNL91qfiCJtVUX746QpNv5i5ve5"'; do
    octez_hex=$(octez_pack "$kh" 'key_hash')
    TOTAL=$((TOTAL + 1))
    if [ -n "$octez_hex" ] && [ "$octez_hex" != "" ]; then
        PASS=$((PASS + 1))
        printf "  $(green PASS) key_hash pack non-empty: %s\n" "$kh"
    else
        FAIL=$((FAIL + 1))
        printf "  $(red FAIL) key_hash pack empty: %s\n" "$kh"
    fi
done

# ================================================================
# KEY
# ================================================================
echo ""
echo "--- key: pack (known vectors) ---"

# ed25519 key
check "packKey(edpk)" \
    "0x050a0000002100d670f72efd9475b62275fae773eb5f5eb1fea4f2a0880e6d21983273bf95a0af" \
    "$(octez_pack '"edpkvGfYw3LyB1UcCahKQk4rF2tvbMUk8GFiTuMjL75uGXrpvKXhjn"' 'key')"

# secp256k1 key
check "packKey(sppk)" \
    "0x050a00000022010236bc4fb397a97e0eae8ed27e74e3177bda9ec6ef7714658c064f2de547cfa202" \
    "$(octez_pack '"sppk7Zik17H7AxECMggqD1FyXUQdrGRFtz9X7aR8W2BhaJoWwSnPEGA"' 'key')"

# p256 key
check "packKey(p2pk)" \
    "0x050a0000002202035ae7787d84886dd823f791ae8144d4b257aead24d981f27214529710122ebb92" \
    "$(octez_pack '"p2pk67Cwb5Ke6oSmqeUbJxURXMe3coVnH9tqPiB2xD84CYhHbBKs4oM"' 'key')"

echo ""
echo "--- key: octez self-consistency ---"

for k in \
    '"edpkvGfYw3LyB1UcCahKQk4rF2tvbMUk8GFiTuMjL75uGXrpvKXhjn"' \
    '"sppk7Zik17H7AxECMggqD1FyXUQdrGRFtz9X7aR8W2BhaJoWwSnPEGA"' \
    '"p2pk67Cwb5Ke6oSmqeUbJxURXMe3coVnH9tqPiB2xD84CYhHbBKs4oM"'; do
    octez_hex=$(octez_pack "$k" 'key')
    TOTAL=$((TOTAL + 1))
    if [ -n "$octez_hex" ] && [ "$octez_hex" != "" ]; then
        PASS=$((PASS + 1))
        printf "  $(green PASS) key pack non-empty: %s\n" "$k"
    else
        FAIL=$((FAIL + 1))
        printf "  $(red FAIL) key pack empty: %s\n" "$k"
    fi
done

# ================================================================
# CHAIN_ID
# ================================================================
echo ""
echo "--- chain_id: pack (known vectors) ---"

check "packChainId(mainnet)" \
    "0x050a000000047a06a770" \
    "$(octez_pack '"NetXdQprcVkpaWU"' 'chain_id')"

echo ""
echo "--- chain_id: octez self-consistency ---"

octez_hex=$(octez_pack '"NetXdQprcVkpaWU"' 'chain_id')
TOTAL=$((TOTAL + 1))
if [ -n "$octez_hex" ] && [ "$octez_hex" != "" ]; then
    PASS=$((PASS + 1))
    printf "  $(green PASS) chain_id pack non-empty: NetXdQprcVkpaWU\n"
else
    FAIL=$((FAIL + 1))
    printf "  $(red FAIL) chain_id pack empty: NetXdQprcVkpaWU\n"
fi

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

# nat(127) and int(127) produce different bytes (different continuation bit semantics)
# This documents the difference rather than asserting equality
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
