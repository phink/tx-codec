/-
  Recursive implementation of Micheline encode/decode using List (Fin 256),
  structurally identical to Solidity.

  Architecture:
    Micheline.lean (spec) <-proven equiv-> Implementation.lean (Solidity-shaped) <-transpiler-> Solidity

  Every function here uses pure structural recursion (no while loops,
  no do-notation, no Id.run). The recursion maps 1:1 to recursive
  Solidity function calls.
-/

import MichelinePack.Micheline

namespace Implementation

-- ============================================================
-- Error types for decoders
-- ============================================================

inductive DecodeError where
  | inputTruncated : DecodeError
  | natNegative : DecodeError
  | negativeZero : DecodeError
  | trailingZeroByte : DecodeError
  | trailingBytes : DecodeError
  | intOverflow : DecodeError
  | invalidVersionByte : DecodeError
  | unexpectedNodeTag : DecodeError
  | invalidBoolTag : DecodeError
  | invalidEncoding : DecodeError  -- generic fallback
deriving Repr, DecidableEq

/-- Helper to construct a Fin 256 from a Nat with a proof. -/
private def byte (n : Nat) (h : n < 256 := by omega) : Fin 256 := ⟨n, h⟩

-- ============================================================
-- Error bridge
-- ============================================================

/-- Convert Except DecodeError to Option (bridge for equivalence proofs) -/
@[simp] def toOption : Except DecodeError α → Option α
  | .ok a => some a
  | .error _ => none

-- ============================================================
-- Encode nat: recursive, Solidity-shaped
-- ============================================================

/-- Encode continuation bytes.
    Maps to: function _encodeZarithTail(uint256 rest) returns (bytes memory) -/
def encodeTail (rest : Nat) : List (Fin 256) :=
  if rest = 0 then []
  else if h : rest < 128 then [⟨rest, by omega⟩]
  else ⟨rest % 128 + 128, by omega⟩ :: encodeTail (rest / 128)
termination_by rest
decreasing_by omega

/-- Zarith-encode a natural number.
    Maps to: function _encodeZarithNat(uint256 n) returns (bytes memory) -/
def encode (n : Nat) : List (Fin 256) :=
  let low6 := n % 64
  let rest := n / 64
  if rest >= 1 then
    ⟨low6 + 128, by omega⟩ :: encodeTail rest
  else
    [⟨low6, by omega⟩]

-- ============================================================
-- Decode nat: recursive, Solidity-shaped
-- ============================================================

/-- Decode continuation bytes (offset-based).
    Maps to: function _decodeZarithTail(bytes memory data, uint256 offset, uint256 shift)
             returns (uint256 value, uint256 newOffset) -/
def decodeTail (data : List (Fin 256)) (offset shift : Nat) : Except DecodeError (Nat × Nat) :=
  if h : offset < data.length then
    let b := (data[offset]).val
    if b >= 128 then
      match decodeTail data (offset + 1) (shift + 7) with
      | .error e => .error e
      | .ok (rv, newOff) => .ok (b % 128 * 2 ^ shift + rv, newOff)
    else
      if b = 0 then .error .trailingZeroByte
      else .ok (b * 2 ^ shift, offset + 1)
  else .error .inputTruncated
termination_by data.length - offset

/-- Zarith-decode from a byte list (offset-based).
    Maps to: function _decodeZarithNat(bytes memory data, uint256 offset)
             returns (uint256 value, uint256 newOffset) -/
def decode (data : List (Fin 256)) (offset : Nat) : Except DecodeError (Nat × Nat) :=
  if h : offset < data.length then
    let first := (data[offset]).val
    if first >= 128 then
      if first >= 192 then .error .natNegative
      else
        match decodeTail data (offset + 1) 6 with
        | .error e => .error e
        | .ok (tv, newOff) => .ok (first % 64 + tv, newOff)
    else if first >= 64 then .error .natNegative
    else .ok (first, offset + 1)
  else .error .inputTruncated

-- ============================================================
-- Equivalence proofs: Implementation <-> Micheline
-- ============================================================

theorem encodeTail_eq (n : Nat) : encodeTail n = Micheline.encodeTail n := by
  induction n using Nat.strongRecOn with
  | ind n ih =>
    unfold encodeTail Micheline.encodeTail
    by_cases h0 : n = 0
    · simp [h0]
    · simp only [h0, ite_false]
      split
      · rfl
      · rename_i hge
        congr 1
        exact ih (n / 128) (Nat.div_lt_self (by omega) (by omega))

theorem encode_eq (n : Nat) : encode n = Micheline.encode n := by
  unfold encode Micheline.encode
  by_cases hn : n < 64
  · have : n % 64 = n := Nat.mod_eq_of_lt hn
    simp only [hn, dite_true, show ¬(n / 64 ≥ 1) from by omega, ite_false, this]
  · simp only [show ¬(n < 64) from hn, dite_false, show n / 64 ≥ 1 from by omega, ite_true,
               encodeTail_eq]

-- Bridge lemma: getElem on a list equals head of its drop
private theorem getElem_eq_head_drop {α : Type} (data : List α) (offset : Nat) (h : offset < data.length) :
    data[offset] = (data.drop offset).head (by simp; omega) := by
  induction data generalizing offset with
  | nil => simp at h
  | cons x xs ih =>
    cases offset with
    | zero => simp
    | succ n =>
      simp only [List.drop_succ_cons]
      exact ih n (by simp at h; omega)

-- Bridge lemma: drop (offset+1) = tail of drop offset
private theorem drop_succ_eq_drop_tail {α : Type} (data : List α) (offset : Nat) (h : offset < data.length) :
    data.drop (offset + 1) = (data.drop offset).tail := by
  induction data generalizing offset with
  | nil => simp at h
  | cons x xs ih =>
    cases offset with
    | zero => simp
    | succ n =>
      simp only [List.drop_succ_cons]
      exact ih n (by simp at h; omega)

private theorem drop_eq_cons {α : Type} (data : List α) (offset : Nat) (hlt : offset < data.length) :
    data.drop offset = data[offset] :: data.drop (offset + 1) :=
  (List.getElem_cons_drop hlt).symm

@[simp] theorem toOption_ok (a : α) : toOption (.ok a : Except DecodeError α) = some a := rfl
@[simp] theorem toOption_error (e : DecodeError) : toOption (.error e : Except DecodeError α) = none := rfl

theorem toOption_eq_some {x : Except DecodeError α} {a : α} (h : x.toOption = some a) : x = .ok a := by
  cases x with
  | ok v => exact congrArg _ (Option.some.inj h)
  | error e => exact absurd h (by intro habs; cases habs)

theorem toOption_eq_none {x : Except DecodeError α} (h : toOption x = none) : ∃ e, x = .error e := by
  cases x with
  | ok v => exact absurd h (by simp [toOption])
  | error e => exact ⟨e, rfl⟩

theorem decodeTail_eq (data : List (Fin 256)) (offset shift : Nat) (h : offset ≤ data.length) :
    (decodeTail data offset shift).toOption =
    (Micheline.decodeTail (data.drop offset) shift).map
      (fun (v, rem) => (v, data.length - rem.length)) := by
  unfold decodeTail
  by_cases hlt : offset < data.length
  · simp only [hlt, dite_true]
    rw [drop_eq_cons data offset hlt]; simp only [Micheline.decodeTail]
    by_cases hge128 : (data[offset]).val ≥ 128
    · simp only [hge128, ite_true]
      have hoff1 : offset + 1 ≤ data.length := by omega
      have ih := decodeTail_eq data (offset + 1) (shift + 7) hoff1
      match hd : decodeTail data (offset + 1) (shift + 7),
            hm : Micheline.decodeTail (data.drop (offset + 1)) (shift + 7) with
      | .ok (rv, newOff), some (rv', rem) =>
        rw [hd, hm] at ih
        have ih' : some (rv, newOff) = some (rv', data.length - rem.length) := ih
        have ⟨hrv, hoff⟩ := Prod.mk.inj (Option.some.inj ih')
        show some ((data[offset]).val % 128 * 2 ^ shift + rv, newOff) =
             some ((data[offset]).val % 128 * 2 ^ shift + rv', data.length - rem.length)
        rw [hrv, hoff]
      | .ok p, none =>
        rw [hd, hm] at ih; have : some p = none := ih; simp at this
      | .error e, some _ =>
        rw [hd, hm] at ih; have : (none : Option _) = some _ := ih; simp at this
      | .error _, none => rfl
    · simp only [hge128, ite_false]
      by_cases hzero : (data[offset]).val = 0
      · simp only [hzero, ite_true]
        show none = Option.map _ none; rfl
      · simp only [hzero, ite_false]
        show some _ = Option.map _ (some _)
        simp [Option.map]; omega
  · simp only [hlt, dite_false]
    have heq : offset = data.length := by omega
    subst heq; simp [List.drop_length, Micheline.decodeTail, Option.map]
    rfl
termination_by data.length - offset

theorem decode_eq (data : List (Fin 256)) (offset : Nat) (h : offset ≤ data.length) :
    (decode data offset).toOption =
    (Micheline.decode (data.drop offset)).map
      (fun (v, rem) => (v, data.length - rem.length)) := by
  unfold decode
  by_cases hlt : offset < data.length
  · simp only [hlt, dite_true]
    rw [drop_eq_cons data offset hlt]; simp only [Micheline.decode]
    by_cases hge128 : (data[offset]).val ≥ 128
    · simp only [hge128, ite_true]
      by_cases hge192 : (data[offset]).val ≥ 192
      · simp [hge192, Option.map]; rfl
      · simp only [hge192, ite_false]
        have hoff1 : offset + 1 ≤ data.length := by omega
        have ih := decodeTail_eq data (offset + 1) 6 hoff1
        match hd : decodeTail data (offset + 1) 6,
              hm : Micheline.decodeTail (data.drop (offset + 1)) 6 with
        | .ok (tv, newOff), some (tv', rem) =>
          rw [hd, hm] at ih
          have ih' : some (tv, newOff) = some (tv', data.length - rem.length) := ih
          have ⟨htv, hoff⟩ := Prod.mk.inj (Option.some.inj ih')
          show some ((data[offset]).val % 64 + tv, newOff) =
               some ((data[offset]).val % 64 + tv', data.length - rem.length)
          rw [htv, hoff]
        | .ok p, none =>
          rw [hd, hm] at ih; have : some p = none := ih; simp at this
        | .error e, some _ =>
          rw [hd, hm] at ih; have : (none : Option _) = some _ := ih; simp at this
        | .error _, none => rfl
    · simp only [hge128, ite_false]
      by_cases hge64 : (data[offset]).val ≥ 64
      · simp [hge64, Option.map]; rfl
      · simp only [hge64, ite_false]
        show some _ = some _; congr 1; simp [List.length_drop]; omega
  · have : offset = data.length := by omega
    subst this; simp [List.drop_length, Micheline.decode, Option.map]; rfl

-- ============================================================
-- Roundtrip follows from equivalence + Micheline roundtrip
-- ============================================================

theorem decode_encode (n : Nat) : decode (encode n) 0 = .ok (n, (encode n).length) := by
  have heq := encode_eq n
  have h := decode_eq (encode n) 0 (by omega)
  rw [List.drop_zero, heq, Micheline.decode_encode] at h
  rw [← heq] at h
  simp [Option.map] at h
  exact toOption_eq_some h

-- ============================================================
-- Signed integer encoding
-- ============================================================

/-- Encode a signed integer.
    Maps to: function _encodeZarithInt(int256 z) returns (bytes memory) -/
def encodeInt : Int → List (Fin 256)
  | .ofNat n => encode n
  | .negSucc n =>
    let a := n + 1
    if h : a < 64 then [⟨a + 64, by omega⟩]
    else ⟨a % 64 + 64 + 128, by omega⟩ :: encodeTail (a / 64)

/-- Decode zarith bytes to a signed integer (offset-based).
    Maps to: function _decodeZarithInt(bytes memory data, uint256 offset)
             returns (int256 value, uint256 newOffset) -/
def decodeInt (data : List (Fin 256)) (offset : Nat) : Except DecodeError (Int × Nat) :=
  if h : offset < data.length then
    let first := (data[offset]).val
    if first < 64 then
      .ok (Int.ofNat first, offset + 1)
    else if first < 128 then
      if first = 64 then .error .negativeZero
      else .ok (-Int.ofNat (first - 64), offset + 1)
    else if first < 192 then
      match decodeTail data (offset + 1) 6 with
      | .error e => .error e
      | .ok (tv, newOff) => .ok (Int.ofNat (first % 64 + tv), newOff)
    else
      match decodeTail data (offset + 1) 6 with
      | .error e => .error e
      | .ok (tv, newOff) => .ok (-Int.ofNat (first % 64 + tv), newOff)
  else .error .inputTruncated

-- ============================================================
-- Uint32BE (length prefix)
-- ============================================================

def encodeUint32BE (n : Nat) : List (Fin 256) :=
  [⟨n / 16777216 % 256, by omega⟩, ⟨n / 65536 % 256, by omega⟩,
   ⟨n / 256 % 256, by omega⟩, ⟨n % 256, by omega⟩]

def decodeUint32BE (data : List (Fin 256)) (offset : Nat) : Option (Nat × Nat) :=
  if offset + 4 ≤ data.length then
    let b0 := (data.getD offset ⟨0, by omega⟩).val
    let b1 := (data.getD (offset + 1) ⟨0, by omega⟩).val
    let b2 := (data.getD (offset + 2) ⟨0, by omega⟩).val
    let b3 := (data.getD (offset + 3) ⟨0, by omega⟩).val
    some (b0 * 16777216 + b1 * 65536 + b2 * 256 + b3, offset + 4)
  else none

-- ============================================================
-- PACK / UNPACK wrappers
-- ============================================================

def packNat (n : Nat) : List (Fin 256) :=
  [byte 0x05, byte 0x00] ++ encode n

def unpackNat (bytes : List (Fin 256)) : Except DecodeError Nat :=
  if bytes.length < 2 then .error .inputTruncated
  else if (bytes.getD 0 ⟨0, by omega⟩).val != 0x05 then .error .invalidVersionByte
  else if (bytes.getD 1 ⟨0, by omega⟩).val != 0x00 then .error .unexpectedNodeTag
  else
    match decode bytes 2 with
    | .ok (v, newOff) => if newOff = bytes.length then .ok v else .error .trailingBytes
    | .error e => .error e

def packInt (z : Int) : List (Fin 256) :=
  [byte 0x05, byte 0x00] ++ encodeInt z

def unpackInt (bytes : List (Fin 256)) : Except DecodeError Int :=
  if bytes.length < 2 then .error .inputTruncated
  else if (bytes.getD 0 ⟨0, by omega⟩).val != 0x05 then .error .invalidVersionByte
  else if (bytes.getD 1 ⟨0, by omega⟩).val != 0x00 then .error .unexpectedNodeTag
  else
    match decodeInt bytes 2 with
    | .ok (v, newOff) => if newOff = bytes.length then .ok v else .error .trailingBytes
    | .error e => .error e

-- ============================================================
-- Bool
-- ============================================================

def packBool (b : Bool) : List (Fin 256) :=
  if b then [byte 0x05, byte 0x03, byte 0x0A]
  else [byte 0x05, byte 0x03, byte 0x03]

def unpackBool (bytes : List (Fin 256)) : Option Bool :=
  match bytes with
  | [a, b, c] =>
    if a.val = 0x05 ∧ b.val = 0x03 ∧ c.val = 0x0A then some true
    else if a.val = 0x05 ∧ b.val = 0x03 ∧ c.val = 0x03 then some false
    else none
  | _ => none

-- ============================================================
-- Unit
-- ============================================================

def packUnit : List (Fin 256) := [byte 0x05, byte 0x03, byte 0x0B]

def unpackUnit (bytes : List (Fin 256)) : Option Unit :=
  match bytes with
  | [a, b, c] =>
    if a.val = 0x05 ∧ b.val = 0x03 ∧ c.val = 0x0B then some ()
    else none
  | _ => none

-- ============================================================
-- String
-- ============================================================

def packString (s : List (Fin 256)) : List (Fin 256) :=
  [byte 0x05, byte 0x01] ++ encodeUint32BE s.length ++ s

def unpackString (bytes : List (Fin 256)) : Option (List (Fin 256)) :=
  match bytes with
  | first :: second :: rest =>
    if first.val = 0x05 ∧ second.val = 0x01 then
      match Micheline.decodeUint32BE rest with
      | some (len, payload) =>
        if payload.length = len then some payload else none
      | none => none
    else none
  | _ => none

-- ============================================================
-- Inner Micheline encoders (no 0x05 prefix)
-- ============================================================

def encodeNatM (n : Nat) : List (Fin 256) := [byte 0x00] ++ encode n
def encodeIntM (z : Int) : List (Fin 256) := [byte 0x00] ++ encodeInt z
def encodeBoolM (b : Bool) : List (Fin 256) :=
  if b then [byte 0x03, byte 0x0A] else [byte 0x03, byte 0x03]
def encodeUnitM : List (Fin 256) := [byte 0x03, byte 0x0B]
def encodeStringM (s : List (Fin 256)) : List (Fin 256) :=
  [byte 0x01] ++ encodeUint32BE s.length ++ s

-- ============================================================
-- Bytes: node tag 0x0A + uint32be(len) + raw bytes
-- ============================================================

def encodeBytesMM (data : List (Fin 256)) : List (Fin 256) :=
  [byte 0x0A] ++ encodeUint32BE data.length ++ data

def packBytes (data : List (Fin 256)) : List (Fin 256) :=
  [byte 0x05] ++ encodeBytesMM data

def unpackBytes (bytes : List (Fin 256)) : Option (List (Fin 256)) :=
  match bytes with
  | first :: second :: rest =>
    if first.val = 0x05 ∧ second.val = 0x0A then
      match Micheline.decodeUint32BE rest with
      | some (len, payload) =>
        if payload.length = len then some payload else none
      | none => none
    else none
  | _ => none

-- ============================================================
-- Composite types: pair, or, option, list
-- ============================================================

def encodePairM (a b : List (Fin 256)) : List (Fin 256) := [byte 0x07, byte 0x07] ++ a ++ b
def encodeLeftM (a : List (Fin 256)) : List (Fin 256) := [byte 0x05, byte 0x05] ++ a
def encodeRightM (b : List (Fin 256)) : List (Fin 256) := [byte 0x05, byte 0x08] ++ b
def encodeSomeM (a : List (Fin 256)) : List (Fin 256) := [byte 0x05, byte 0x09] ++ a
def encodeNoneM : List (Fin 256) := [byte 0x03, byte 0x06]
def encodeListM (items : List (List (Fin 256))) : List (Fin 256) :=
  let payload := items.flatten
  [byte 0x02] ++ encodeUint32BE payload.length ++ payload

-- PACK wrappers (add 0x05 version byte)
def packPairV (a b : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodePairM a b
def packLeftV (a : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodeLeftM a
def packRightV (b : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodeRightM b
def packSomeV (a : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodeSomeM a
def packNoneV : List (Fin 256) := [byte 0x05] ++ encodeNoneM
def packListV (items : List (List (Fin 256))) : List (Fin 256) := [byte 0x05] ++ encodeListM items

-- Unpack for composite types
def unpackPairV (packed : List (Fin 256)) : Option (List (Fin 256) × List (Fin 256)) :=
  match packed with
  | a :: b :: c :: rest =>
    if a.val = 0x05 ∧ b.val = 0x07 ∧ c.val = 0x07 then
      match Micheline.michelineNodeSize rest 0 with
      | some n =>
        if n ≤ rest.length then
          some (rest.take n, rest.drop n)
        else none
      | none => none
    else none
  | _ => none

def unpackOrV (packed : List (Fin 256)) : Option (Bool × List (Fin 256)) :=
  match packed with
  | a :: b :: c :: rest =>
    if a.val = 0x05 ∧ b.val = 0x05 ∧ c.val = 0x05 then some (true, rest)
    else if a.val = 0x05 ∧ b.val = 0x05 ∧ c.val = 0x08 then some (false, rest)
    else none
  | _ => none

def unpackOptionV (packed : List (Fin 256)) : Option (Bool × List (Fin 256)) :=
  match packed with
  | a :: b :: c :: rest =>
    if a.val = 0x05 ∧ b.val = 0x05 ∧ c.val = 0x09 then some (true, rest)
    else if a.val = 0x05 ∧ b.val = 0x03 ∧ c.val = 0x06 ∧ rest = [] then some (false, [])
    else none
  | _ => none

def unpackListV (packed : List (Fin 256)) : Option (List (Fin 256)) :=
  match packed with
  | first :: second :: b0 :: b1 :: b2 :: b3 :: rest =>
    if first.val = 0x05 ∧ second.val = 0x02 then
      let len := b0.val * 16777216 + b1.val * 65536 + b2.val * 256 + b3.val
      if rest.length = len then some rest else none
    else none
  | _ => none

-- ============================================================
-- Map: Sequence of Elt pairs
-- ============================================================

def encodeEltM (key val : List (Fin 256)) : List (Fin 256) :=
  [byte 0x07, byte 0x04] ++ key ++ val

def encodeMapM (elts : List (List (Fin 256))) : List (Fin 256) :=
  let payload := elts.flatten
  [byte 0x02] ++ encodeUint32BE payload.length ++ payload

def packMapV (elts : List (List (Fin 256))) : List (Fin 256) :=
  [byte 0x05] ++ encodeMapM elts

def unpackMapV (packed : List (Fin 256)) : Option (List (Fin 256)) :=
  unpackListV packed

-- ============================================================
-- Set: identical to list at binary level
-- ============================================================

def encodeSetM := @encodeListM
def packSetV := @packListV
def unpackSetV := @unpackListV

-- ============================================================
-- Binary types: address, key_hash, key, signature, chain_id
-- All use Bytes node (0x0A)
-- ============================================================

def encodeAddressM (addrBytes : List (Fin 256)) : List (Fin 256) := encodeBytesMM addrBytes
def packAddress (addrBytes : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodeAddressM addrBytes
def unpackAddress (packed : List (Fin 256)) : Option (List (Fin 256)) := unpackBytes packed

def encodeKeyHashM (hashBytes : List (Fin 256)) : List (Fin 256) := encodeBytesMM hashBytes
def packKeyHash (hashBytes : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodeKeyHashM hashBytes
def unpackKeyHash (packed : List (Fin 256)) : Option (List (Fin 256)) := unpackBytes packed

def encodeKeyM (keyBytes : List (Fin 256)) : List (Fin 256) := encodeBytesMM keyBytes
def packKey (keyBytes : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodeKeyM keyBytes
def unpackKey (packed : List (Fin 256)) : Option (List (Fin 256)) := unpackBytes packed

def encodeSignatureM (sigBytes : List (Fin 256)) : List (Fin 256) := encodeBytesMM sigBytes
def packSignature (sigBytes : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodeSignatureM sigBytes
def unpackSignature (packed : List (Fin 256)) : Option (List (Fin 256)) := unpackBytes packed

def encodeChainIdM (idBytes : List (Fin 256)) : List (Fin 256) := encodeBytesMM idBytes
def packChainId (idBytes : List (Fin 256)) : List (Fin 256) := [byte 0x05] ++ encodeChainIdM idBytes
def unpackChainId (packed : List (Fin 256)) : Option (List (Fin 256)) := unpackBytes packed

-- ============================================================
-- Mutez / Timestamp
-- ============================================================

def packMutez (v : Nat) : List (Fin 256) :=
  [byte 0x05, byte 0x00] ++ encode v

def unpackMutez (bytes : List (Fin 256)) : Except DecodeError Nat :=
  match unpackNat bytes with
  | .ok n => if n < 2 ^ 63 then .ok n else .error .intOverflow
  | .error e => .error e

def packTimestamp (v : Int) : List (Fin 256) :=
  [byte 0x05, byte 0x00] ++ encodeInt v

def unpackTimestamp (bytes : List (Fin 256)) : Except DecodeError Int :=
  match unpackInt bytes with
  | .ok z => if z ≥ -(2 ^ 63 : Int) ∧ z < (2 ^ 63 : Int) then .ok z else .error .intOverflow
  | .error e => .error e

-- ============================================================
-- Equivalence proofs: all types
-- ============================================================

-- Int encode/decode equivalence

theorem encodeInt_eq (z : Int) : encodeInt z = Micheline.encodeInt z := by
  cases z with
  | ofNat n => simp [encodeInt, Micheline.encodeInt, encode_eq]
  | negSucc n => simp [encodeInt, Micheline.encodeInt, encodeTail_eq]

theorem decodeInt_eq (data : List (Fin 256)) (offset : Nat) (h : offset ≤ data.length) :
    (decodeInt data offset).toOption =
    (Micheline.decodeInt (data.drop offset)).map
      (fun (v, rem) => (v, data.length - rem.length)) := by
  unfold decodeInt
  by_cases hlt : offset < data.length
  · simp only [hlt, dite_true]
    rw [drop_eq_cons data offset hlt]; simp only [Micheline.decodeInt]
    by_cases h64 : (data[offset]).val < 64
    · simp only [h64, ite_true, Option.map]; show some _ = some _; congr 1; simp [List.length_drop]; omega
    · simp only [h64, ite_false]
      by_cases h128 : (data[offset]).val < 128
      · simp only [h128, ite_true]
        by_cases h64eq : (data[offset]).val = 64
        · simp only [h64eq, ite_true, Option.map]; rfl
        · simp only [h64eq, ite_false, Option.map]; show some _ = some _; congr 1; simp [List.length_drop]; omega
      · simp only [h128, ite_false]
        have hoff1 : offset + 1 ≤ data.length := by omega
        have ih := decodeTail_eq data (offset + 1) 6 hoff1
        split
        · -- h192 true: positive multi-byte
          match hd : decodeTail data (offset + 1) 6,
                hm : Micheline.decodeTail (data.drop (offset + 1)) 6 with
          | .ok (tv, newOff), some (tv', rem) =>
            rw [hd, hm] at ih
            have ih' : some (tv, newOff) = some (tv', data.length - rem.length) := ih
            have ⟨htv, hoff⟩ := Prod.mk.inj (Option.some.inj ih')
            show some (Int.ofNat ((data[offset]).val % 64 + tv), newOff) =
                 some (Int.ofNat ((data[offset]).val % 64 + tv'), data.length - rem.length)
            rw [htv, hoff]
          | .ok p, none =>
            rw [hd, hm] at ih; have : some p = none := ih; simp at this
          | .error e, some _ =>
            rw [hd, hm] at ih; have : (none : Option _) = some _ := ih; simp at this
          | .error _, none => rfl
        · -- h192 false: negative multi-byte
          match hd : decodeTail data (offset + 1) 6,
                hm : Micheline.decodeTail (data.drop (offset + 1)) 6 with
          | .ok (tv, newOff), some (tv', rem) =>
            rw [hd, hm] at ih
            have ih' : some (tv, newOff) = some (tv', data.length - rem.length) := ih
            have ⟨htv, hoff⟩ := Prod.mk.inj (Option.some.inj ih')
            show some (-Int.ofNat ((data[offset]).val % 64 + tv), newOff) =
                 some (-Int.ofNat ((data[offset]).val % 64 + tv'), data.length - rem.length)
            rw [htv, hoff]
          | .ok p, none =>
            rw [hd, hm] at ih; have : some p = none := ih; simp at this
          | .error e, some _ =>
            rw [hd, hm] at ih; have : (none : Option _) = some _ := ih; simp at this
          | .error _, none => rfl
  · have : offset = data.length := by omega
    subst this; simp [List.drop_length, Micheline.decodeInt, Option.map]; rfl

-- Uint32BE

theorem encodeUint32BE_eq (n : Nat) : encodeUint32BE n = Micheline.encodeUint32BE n := rfl

-- Helper: if l.drop i = x :: xs then l.getD i d = x (for Fin 256)
private theorem getD_of_drop_cons (l : List (Fin 256)) (i : Nat) (x : Fin 256) (xs : List (Fin 256))
    (h : l.drop i = x :: xs) (d : Fin 256) : l.getD i d = x := by
  have hlt : i < l.length := by
    have := congrArg List.length h; simp at this; omega
  simp only [List.getD, List.getElem?_eq_getElem hlt, Option.getD]
  have h1 := getElem_eq_head_drop l i hlt
  simp only [h] at h1; exact h1

-- Pack/Unpack nat

theorem packNat_eq (n : Nat) : packNat n = Micheline.packNat n := by
  show [byte 0x05, byte 0x00] ++ encode n = Micheline.packNat n
  rw [encode_eq]; rfl

-- Helper: toOption for match on decode result with offset check
private theorem toOption_decode_match_offset (data : List (Fin 256)) (offset : Nat)
    (rest : List (Fin 256)) (h_len : data.length > 0)
    (h_eq : (decode data offset).toOption =
      (Micheline.decode rest).map (fun (v, rem) => (v, data.length - rem.length))) :
    (match decode data offset with
     | Except.ok (v, newOff) => if newOff = data.length then Except.ok v
                                else (Except.error DecodeError.trailingBytes : Except DecodeError Nat)
     | Except.error e => Except.error e).toOption =
    (match Micheline.decode rest with
     | some (v, []) => some v
     | _ => none) := by
  match hd : decode data offset, hm : Micheline.decode rest with
  | Except.ok (v, off), some (v', rem) =>
    rw [hd, hm] at h_eq
    have h_eq' : some (v, off) = some (v', data.length - rem.length) := h_eq
    have ⟨hv, hoff⟩ := Prod.mk.inj (Option.some.inj h_eq')
    rw [hv]
    by_cases hempty : rem = []
    · subst hempty; simp only [List.length_nil, Nat.sub_zero] at hoff
      show (if off = data.length then Except.ok v' else _).toOption = _
      simp [hoff]; rfl
    · simp only []
      match rem, hempty with
      | r :: rs, _ =>
        split
        · next heq =>
          exfalso; have h1 : off = data.length - (rs.length + 1) := by rw [hoff]; simp [List.length]
          omega
        · rfl
  | Except.ok _, none =>
    rw [hd, hm] at h_eq; have : some _ = none := h_eq; simp at this
  | Except.error _, some _ =>
    rw [hd, hm] at h_eq; have : (none : Option _) = some _ := h_eq; simp at this
  | Except.error _, none => rfl

theorem unpackNat_eq (bytes : List (Fin 256)) : (unpackNat bytes).toOption = Micheline.unpackNat bytes := by
  match bytes with
  | [] => simp [unpackNat, Micheline.unpackNat]; rfl
  | [_] => simp [unpackNat, Micheline.unpackNat]; rfl
  | first :: second :: rest =>
    simp only [unpackNat, Micheline.unpackNat]
    simp only [show ¬((first :: second :: rest).length < 2) from by simp, ite_false,
               List.getD_cons_zero, List.getD_cons_succ]
    by_cases hf : first.val = 0x05
    · by_cases hs : second.val = 0x00
      · have hcond : first.val = 0x05 ∧ second.val = 0x00 := ⟨hf, hs⟩
        simp only [show (first.val != 0x05) = false from by simp [hf],
                   show (second.val != 0x00) = false from by simp [hs],
                   ite_false, hcond, ite_true]
        exact toOption_decode_match_offset _ 2 rest (by simp)
          (decode_eq (first :: second :: rest) 2 (by simp))
      · simp only [show (first.val != 0x05) = false from by simp [hf],
                   show (second.val != 0x00) = true from by simp [hs],
                   ite_false, ite_true,
                   show ¬(first.val = 0x05 ∧ second.val = 0x00) from fun h => hs h.2,
                   toOption]; rfl
    · simp only [show (first.val != 0x05) = true from by simp [hf], ite_true,
                 show ¬(first.val = 0x05 ∧ second.val = 0x00) from fun h => hf h.1,
                 ite_false, toOption]; rfl

-- Pack/Unpack int

theorem packInt_eq (z : Int) : packInt z = Micheline.packInt z := by
  show [byte 0x05, byte 0x00] ++ encodeInt z = Micheline.packInt z
  rw [encodeInt_eq]; rfl

-- Helper: toOption for match on decodeInt result with offset check
private theorem toOption_decodeInt_match_offset (data : List (Fin 256)) (offset : Nat)
    (rest : List (Fin 256)) (h_len : data.length > 0)
    (h_eq : (decodeInt data offset).toOption =
      (Micheline.decodeInt rest).map (fun (v, rem) => (v, data.length - rem.length))) :
    (match decodeInt data offset with
     | Except.ok (v, newOff) => if newOff = data.length then Except.ok v
                                else (Except.error DecodeError.trailingBytes : Except DecodeError Int)
     | Except.error e => Except.error e).toOption =
    (match Micheline.decodeInt rest with
     | some (v, []) => some v
     | _ => none) := by
  match hd : decodeInt data offset, hm : Micheline.decodeInt rest with
  | Except.ok (v, off), some (v', rem) =>
    rw [hd, hm] at h_eq
    have h_eq' : some (v, off) = some (v', data.length - rem.length) := h_eq
    have ⟨hv, hoff⟩ := Prod.mk.inj (Option.some.inj h_eq')
    rw [hv]
    by_cases hempty : rem = []
    · subst hempty; simp only [List.length_nil, Nat.sub_zero] at hoff
      show (if off = data.length then Except.ok v' else _).toOption = _
      simp [hoff]; rfl
    · match rem, hempty with
      | r :: rs, _ =>
        simp only []
        split
        · next heq =>
          exfalso; have h1 : off = data.length - (rs.length + 1) := by rw [hoff]; simp [List.length]
          omega
        · rfl
  | Except.ok _, none =>
    rw [hd, hm] at h_eq; have : some _ = none := h_eq; simp at this
  | Except.error _, some _ =>
    rw [hd, hm] at h_eq; have : (none : Option _) = some _ := h_eq; simp at this
  | Except.error _, none => rfl

theorem unpackInt_eq (bytes : List (Fin 256)) : (unpackInt bytes).toOption = Micheline.unpackInt bytes := by
  match bytes with
  | [] => simp [unpackInt, Micheline.unpackInt]; rfl
  | [_] => simp [unpackInt, Micheline.unpackInt]; rfl
  | first :: second :: rest =>
    simp only [unpackInt, Micheline.unpackInt]
    simp only [show ¬((first :: second :: rest).length < 2) from by simp, ite_false,
               List.getD_cons_zero, List.getD_cons_succ]
    by_cases hf : first.val = 0x05
    · by_cases hs : second.val = 0x00
      · have hcond : first.val = 0x05 ∧ second.val = 0x00 := ⟨hf, hs⟩
        simp only [show (first.val != 0x05) = false from by simp [hf],
                   show (second.val != 0x00) = false from by simp [hs],
                   ite_false, hcond, ite_true]
        exact toOption_decodeInt_match_offset _ 2 rest (by simp)
          (decodeInt_eq (first :: second :: rest) 2 (by simp))
      · simp only [show (first.val != 0x05) = false from by simp [hf],
                   show (second.val != 0x00) = true from by simp [hs],
                   ite_false, ite_true,
                   show ¬(first.val = 0x05 ∧ second.val = 0x00) from fun h => hs h.2,
                   toOption]; rfl
    · simp only [show (first.val != 0x05) = true from by simp [hf], ite_true,
                 show ¬(first.val = 0x05 ∧ second.val = 0x00) from fun h => hf h.1,
                 ite_false, toOption]; rfl

-- Bool / Unit

theorem packBool_eq (b : Bool) : packBool b = Micheline.packBool b := by
  cases b <;> rfl

theorem unpackBool_eq (bytes : List (Fin 256)) : unpackBool bytes = Micheline.unpackBool bytes := by
  unfold unpackBool Micheline.unpackBool
  split <;> split <;> simp_all

theorem packUnit_eq : packUnit = Micheline.packUnit := rfl

theorem unpackUnit_eq (bytes : List (Fin 256)) : unpackUnit bytes = Micheline.unpackUnit bytes := by
  unfold unpackUnit Micheline.unpackUnit
  split <;> split <;> simp_all

-- String

theorem packString_eq (s : List (Fin 256)) : packString s = Micheline.packString s := by
  show [byte 0x05, byte 0x01] ++ encodeUint32BE s.length ++ s = Micheline.packString s
  rfl

theorem unpackString_eq (bytes : List (Fin 256)) : unpackString bytes = Micheline.unpackString bytes := by
  rfl

-- Bytes

theorem encodeBytesMM_eq (data : List (Fin 256)) : encodeBytesMM data = Micheline.encodeBytesMM data := rfl
theorem packBytes_eq (data : List (Fin 256)) : packBytes data = Micheline.packBytes data := rfl

theorem unpackBytes_eq (bytes : List (Fin 256)) : unpackBytes bytes = Micheline.unpackBytes bytes := by
  rfl

-- Inner Micheline encoders

theorem encodeNatM_eq (n : Nat) : encodeNatM n = Micheline.encodeNatM n := by
  show [byte 0x00] ++ encode n = Micheline.encodeNatM n
  rw [encode_eq]; rfl

theorem encodeIntM_eq (z : Int) : encodeIntM z = Micheline.encodeIntM z := by
  show [byte 0x00] ++ encodeInt z = Micheline.encodeIntM z
  rw [encodeInt_eq]; rfl

theorem encodeBoolM_eq (b : Bool) : encodeBoolM b = Micheline.encodeBoolM b := by
  cases b <;> rfl

theorem encodeUnitM_eq : encodeUnitM = Micheline.encodeUnitM := rfl

theorem encodeStringM_eq (s : List (Fin 256)) : encodeStringM s = Micheline.encodeStringM s := rfl

-- Composite types

theorem encodePairM_eq (a b : List (Fin 256)) : encodePairM a b = Micheline.encodePairM a b := rfl
theorem encodeLeftM_eq (a : List (Fin 256)) : encodeLeftM a = Micheline.encodeLeftM a := rfl
theorem encodeRightM_eq (b : List (Fin 256)) : encodeRightM b = Micheline.encodeRightM b := rfl
theorem encodeSomeM_eq (a : List (Fin 256)) : encodeSomeM a = Micheline.encodeSomeM a := rfl
theorem encodeNoneM_eq : encodeNoneM = Micheline.encodeNoneM := rfl

theorem encodeListM_eq (items : List (List (Fin 256))) : encodeListM items = Micheline.encodeListM items := rfl

theorem packPairV_eq (a b : List (Fin 256)) : packPairV a b = Micheline.packPairV a b := rfl
theorem packLeftV_eq (a : List (Fin 256)) : packLeftV a = Micheline.packLeftV a := rfl
theorem packRightV_eq (b : List (Fin 256)) : packRightV b = Micheline.packRightV b := rfl
theorem packSomeV_eq (a : List (Fin 256)) : packSomeV a = Micheline.packSomeV a := rfl
theorem packNoneV_eq : packNoneV = Micheline.packNoneV := rfl

theorem packListV_eq (items : List (List (Fin 256))) : packListV items = Micheline.packListV items := rfl

theorem unpackPairV_eq (packed : List (Fin 256)) : unpackPairV packed = Micheline.unpackPairV packed := rfl
theorem unpackOrV_eq (packed : List (Fin 256)) : unpackOrV packed = Micheline.unpackOrV packed := rfl
theorem unpackOptionV_eq (packed : List (Fin 256)) : unpackOptionV packed = Micheline.unpackOptionV packed := rfl
theorem unpackListV_eq (packed : List (Fin 256)) : unpackListV packed = Micheline.unpackListV packed := rfl

-- Map / Set

theorem encodeEltM_eq (key val : List (Fin 256)) : encodeEltM key val = Micheline.encodeEltM key val := rfl

theorem encodeMapM_eq (elts : List (List (Fin 256))) : encodeMapM elts = Micheline.encodeMapM elts := rfl
theorem packMapV_eq (elts : List (List (Fin 256))) : packMapV elts = Micheline.packMapV elts := rfl

theorem unpackMapV_eq (packed : List (Fin 256)) : unpackMapV packed = Micheline.unpackMapV packed := rfl

-- Binary types

theorem packAddress_eq (a : List (Fin 256)) : packAddress a = Micheline.packAddress a := rfl

theorem unpackAddress_eq (p : List (Fin 256)) : unpackAddress p = Micheline.unpackAddress p := rfl

theorem packKeyHash_eq (h : List (Fin 256)) : packKeyHash h = Micheline.packKeyHash h := rfl

theorem unpackKeyHash_eq (p : List (Fin 256)) : unpackKeyHash p = Micheline.unpackKeyHash p := rfl

theorem packKey_eq (k : List (Fin 256)) : packKey k = Micheline.packKey k := rfl

theorem unpackKey_eq (p : List (Fin 256)) : unpackKey p = Micheline.unpackKey p := rfl

theorem packSignature_eq (s : List (Fin 256)) : packSignature s = Micheline.packSignature s := rfl

theorem unpackSignature_eq (p : List (Fin 256)) : unpackSignature p = Micheline.unpackSignature p := rfl

theorem packChainId_eq (i : List (Fin 256)) : packChainId i = Micheline.packChainId i := rfl

theorem unpackChainId_eq (p : List (Fin 256)) : unpackChainId p = Micheline.unpackChainId p := rfl

-- Mutez / Timestamp

theorem packMutez_eq (v : Nat) : packMutez v = Micheline.packMutez v := by
  show [byte 0x05, byte 0x00] ++ encode v = Micheline.packMutez v
  rw [encode_eq]; rfl

theorem unpackMutez_eq (bytes : List (Fin 256)) : (unpackMutez bytes).toOption = Micheline.unpackMutez bytes := by
  simp only [unpackMutez, Micheline.unpackMutez]
  have h := unpackNat_eq bytes
  match hnat : unpackNat bytes with
  | .ok n =>
    rw [hnat] at h; rw [show Micheline.unpackNat bytes = some n from h.symm]
    by_cases hlt : n < 2 ^ 63
    · simp [hlt]; rfl
    · simp [hlt]; rfl
  | .error _ =>
    rw [hnat] at h; rw [show Micheline.unpackNat bytes = none from h.symm]; rfl

theorem packTimestamp_eq (v : Int) : packTimestamp v = Micheline.packTimestamp v := by
  show [byte 0x05, byte 0x00] ++ encodeInt v = Micheline.packTimestamp v
  rw [encodeInt_eq]; rfl

theorem unpackTimestamp_eq (bytes : List (Fin 256)) : (unpackTimestamp bytes).toOption = Micheline.unpackTimestamp bytes := by
  simp only [unpackTimestamp, Micheline.unpackTimestamp]
  have h := unpackInt_eq bytes
  match hint : unpackInt bytes with
  | .ok z =>
    rw [hint] at h; rw [show Micheline.unpackInt bytes = some z from h.symm]
    show (if z ≥ -(2 ^ 63 : Int) ∧ z < (2 ^ 63 : Int) then Except.ok z
          else Except.error DecodeError.intOverflow).toOption =
         (if z ≥ -(2 ^ 63 : Int) ∧ z < (2 ^ 63 : Int) then some z else none)
    split <;> rfl
  | .error _ =>
    rw [hint] at h; rw [show Micheline.unpackInt bytes = none from h.symm]; rfl

-- ============================================================
-- Roundtrip follows from equivalence + Micheline roundtrip
-- ============================================================

theorem decodeInt_encodeInt (z : Int) :
    decodeInt (encodeInt z) 0 = .ok (z, (encodeInt z).length) := by
  have heq := encodeInt_eq z
  have h := decodeInt_eq (encodeInt z) 0 (by omega)
  rw [List.drop_zero, heq, Micheline.decodeInt_encodeInt] at h
  rw [← heq] at h
  simp [Option.map] at h
  exact toOption_eq_some h

-- ============================================================
-- Quick tests
-- ============================================================

#eval encode 0       -- [⟨0, _⟩]
#eval encode 42      -- [⟨42, _⟩]
#eval encode 64      -- [⟨128, _⟩, ⟨1, _⟩]
#eval encode 128     -- [⟨128, _⟩, ⟨2, _⟩]
#eval encode 8192    -- [⟨128, _⟩, ⟨128, _⟩, ⟨1, _⟩]
#eval encodeInt (-42 : Int)   -- [⟨106, _⟩]
#eval packBool true           -- [⟨5, _⟩, ⟨3, _⟩, ⟨10, _⟩]

-- Offset-based decode tests
#eval decode [⟨0, by omega⟩] 0             -- .ok (0, 1)
#eval decode [⟨42, by omega⟩] 0            -- .ok (42, 1)
#eval decode [⟨128, by omega⟩, ⟨1, by omega⟩] 0        -- .ok (64, 2)
#eval decode [⟨128, by omega⟩, ⟨2, by omega⟩] 0        -- .ok (128, 2)

end Implementation
