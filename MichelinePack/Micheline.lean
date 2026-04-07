-- ============================================================
-- Micheline: Native List (Fin 256) version of Micheline codec
-- All byte lists use Fin 256 — byte validity is structural.
-- ============================================================

namespace Micheline

/-- Helper to construct a Fin 256 from a Nat with a proof. -/
private def byte (n : Nat) (h : n < 256 := by omega) : Fin 256 := ⟨n, h⟩

-- ============================================================
-- Core nat zarith encoding (unsigned)
-- ============================================================

/-- Encode continuation bytes: 7 data bits + continuation bit per byte -/
def encodeTail (n : Nat) : List (Fin 256) :=
  if n = 0 then []
  else if h : n < 128 then [⟨n, by omega⟩]
  else ⟨n % 128 + 128, by omega⟩ :: encodeTail (n / 128)
termination_by n
decreasing_by omega

/-- Encode a natural number as zarith bytes.
    First byte: 6 data bits + sign=0 + continuation.
    Subsequent bytes via encodeTail. -/
def encode (n : Nat) : List (Fin 256) :=
  if h : n < 64 then [⟨n, by omega⟩]
  else ⟨n % 64 + 128, by omega⟩ :: encodeTail (n / 64)

/-- Decode continuation bytes, accumulating value with shift -/
def decodeTail : List (Fin 256) → Nat → Option (Nat × List (Fin 256))
  | [], _ => none
  | b :: rest, shift =>
    if b.val ≥ 128 then
      match decodeTail rest (shift + 7) with
      | none => none
      | some (rv, rem) => some (b.val % 128 * 2 ^ shift + rv, rem)
    else
      if b.val = 0 then none  -- trailing zero rejection
      else some (b.val * 2 ^ shift, rest)

/-- Decode zarith bytes to a natural number.
    Rejects sign bit (bit 6) whether single-byte or multi-byte. -/
def decode : List (Fin 256) → Option (Nat × List (Fin 256))
  | [] => none
  | first :: rest =>
    if first.val ≥ 128 then
      if first.val ≥ 192 then none  -- sign bit set in multi-byte
      else match decodeTail rest 6 with
        | none => none
        | some (tv, rem) => some (first.val % 64 + tv, rem)
    else if first.val ≥ 64 then none  -- sign bit set in single-byte
    else some (first.val, rest)

-- ============================================================
-- Signed integer encoding
-- ============================================================

/-- Encode a signed integer. Same as nat but sets bit 6 (sign) on first byte if negative. -/
def encodeInt : Int → List (Fin 256)
  | .ofNat n => encode n
  | .negSucc n =>
    let a := n + 1
    if h : a < 64 then [⟨a + 64, by omega⟩]
    else have : a % 64 + 64 + 128 < 256 := by omega
         ⟨a % 64 + 64 + 128, this⟩ :: encodeTail (a / 64)

/-- Decode zarith bytes to a signed integer. -/
def decodeInt : List (Fin 256) → Option (Int × List (Fin 256))
  | [] => none
  | first :: rest =>
    if first.val < 64 then
      some (Int.ofNat first.val, rest)
    else if first.val < 128 then
      -- Negative, single byte. Reject negative zero.
      if first.val = 64 then none
      else some (-Int.ofNat (first.val - 64), rest)
    else if first.val < 192 then
      -- Positive, multi-byte
      match decodeTail rest 6 with
      | none => none
      | some (tv, rem) => some (Int.ofNat (first.val % 64 + tv), rem)
    else
      -- Negative, multi-byte
      match decodeTail rest 6 with
      | none => none
      | some (tv, rem) => some (-Int.ofNat (first.val % 64 + tv), rem)

-- ============================================================
-- PACK / UNPACK wrappers
-- ============================================================

def packNat (n : Nat) : List (Fin 256) :=
  [byte 0x05, byte 0x00] ++ encode n

def unpackNat (bytes : List (Fin 256)) : Option Nat :=
  match bytes with
  | first :: second :: rest =>
    if first.val = 0x05 ∧ second.val = 0x00 then
      match decode rest with
      | some (v, []) => some v
      | _ => none
    else none
  | _ => none

def packInt (z : Int) : List (Fin 256) :=
  [byte 0x05, byte 0x00] ++ encodeInt z

def unpackInt (bytes : List (Fin 256)) : Option Int :=
  match bytes with
  | first :: second :: rest =>
    if first.val = 0x05 ∧ second.val = 0x00 then
      match decodeInt rest with
      | some (v, []) => some v
      | _ => none
    else none
  | _ => none

-- ============================================================
-- Bool: Prim node (tag 0x03) with D_True (0x0A) or D_False (0x03)
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
-- Unit: Prim node (tag 0x03) with D_Unit (0x0B)
-- ============================================================

def packUnit : List (Fin 256) := [byte 0x05, byte 0x03, byte 0x0B]

def unpackUnit (bytes : List (Fin 256)) : Option Unit :=
  match bytes with
  | [a, b, c] =>
    if a.val = 0x05 ∧ b.val = 0x03 ∧ c.val = 0x0B then some ()
    else none
  | _ => none

-- ============================================================
-- String: node tag 0x01 + uint32be(len) + utf8 bytes
-- ============================================================

/-- Encode a 32-bit big-endian length -/
def encodeUint32BE (n : Nat) : List (Fin 256) :=
  [⟨n / 16777216 % 256, by omega⟩, ⟨n / 65536 % 256, by omega⟩,
   ⟨n / 256 % 256, by omega⟩, ⟨n % 256, by omega⟩]

/-- Decode a 32-bit big-endian length from 4 bytes -/
def decodeUint32BE : List (Fin 256) → Option (Nat × List (Fin 256))
  | b0 :: b1 :: b2 :: b3 :: rest =>
    some (b0.val * 16777216 + b1.val * 65536 + b2.val * 256 + b3.val, rest)
  | _ => none

def packString (s : List (Fin 256)) : List (Fin 256) :=
  [byte 0x05, byte 0x01] ++ encodeUint32BE s.length ++ s

def unpackString (bytes : List (Fin 256)) : Option (List (Fin 256)) :=
  match bytes with
  | first :: second :: rest =>
    if first.val = 0x05 ∧ second.val = 0x01 then
      match decodeUint32BE rest with
      | some (len, payload) =>
        if payload.length = len then some payload else none
      | none => none
    else none
  | _ => none

-- ============================================================
-- Inner Micheline encoders (no 0x05 prefix — for composite types)
-- ============================================================

def encodeNatM (n : Nat) : List (Fin 256) := [byte 0x00] ++ encode n
def encodeIntM (z : Int) : List (Fin 256) := [byte 0x00] ++ encodeInt z
def encodeBoolM (b : Bool) : List (Fin 256) :=
  if b then [byte 0x03, byte 0x0A] else [byte 0x03, byte 0x03]
def encodeUnitM : List (Fin 256) := [byte 0x03, byte 0x0B]
def encodeStringM (s : List (Fin 256)) : List (Fin 256) :=
  [byte 0x01] ++ encodeUint32BE s.length ++ s

-- ============================================================
-- Composite types: pair, or, option, list
-- ============================================================

/-- Micheline pair node: tag 0x07 (2 args, no annots) + D_Pair (0x07) -/
def encodePairM (a b : List (Fin 256)) : List (Fin 256) := [byte 0x07, byte 0x07] ++ a ++ b
/-- Micheline Left node: tag 0x05 (1 arg, no annots) + D_Left (0x05) -/
def encodeLeftM (a : List (Fin 256)) : List (Fin 256) := [byte 0x05, byte 0x05] ++ a
/-- Micheline Right node: tag 0x05 (1 arg, no annots) + D_Right (0x08) -/
def encodeRightM (b : List (Fin 256)) : List (Fin 256) := [byte 0x05, byte 0x08] ++ b
/-- Micheline Some node: tag 0x05 (1 arg, no annots) + D_Some (0x09) -/
def encodeSomeM (a : List (Fin 256)) : List (Fin 256) := [byte 0x05, byte 0x09] ++ a
/-- Micheline None node: tag 0x03 (0 args, no annots) + D_None (0x06) -/
def encodeNoneM : List (Fin 256) := [byte 0x03, byte 0x06]
/-- Micheline Sequence node: tag 0x02 + uint32be(total_len) + concatenated items -/
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

/-- Scan forward from `pos` in `data` until a byte < 128 is found.
    Returns the position just past that terminal byte. -/
private def skipZarith (data : List (Fin 256)) (pos : Nat) : Option Nat :=
  if h : pos < data.length then
    if (data[pos]).val < 128 then some (pos + 1)
    else skipZarith data (pos + 1)
  else none
termination_by data.length - pos

/-- Count bytes consumed by one Micheline node starting at `offset` in `data`.
    Returns the number of bytes consumed, or none if the data is malformed. -/
def michelineNodeSize (data : List (Fin 256)) (offset : Nat) : Option Nat :=
  if h : offset < data.length then
    let tag := (data[offset]).val
    if tag == 0x00 then -- Int node: scan for terminal byte (< 128)
      match skipZarith data (offset + 1) with
      | some endPos => some (endPos - offset)
      | none => none
    else if tag == 0x01 || tag == 0x02 || tag == 0x0A then
      -- String / Sequence / Bytes: 1 + 4 + len
      if offset + 5 ≤ data.length then
        let b0 := (data.getD (offset + 1) ⟨0, by omega⟩).val
        let b1 := (data.getD (offset + 2) ⟨0, by omega⟩).val
        let b2 := (data.getD (offset + 3) ⟨0, by omega⟩).val
        let b3 := (data.getD (offset + 4) ⟨0, by omega⟩).val
        let len := b0 * 16777216 + b1 * 65536 + b2 * 256 + b3
        if offset + 5 + len ≤ data.length then some (5 + len) else none
      else none
    else if tag == 0x03 then -- Prim(0 args): tag + prim byte
      if offset + 2 ≤ data.length then some 2 else none
    else if tag == 0x05 then -- Prim(1 arg): tag + prim + child
      if offset + 2 ≤ data.length then
        match michelineNodeSize data (offset + 2) with
        | some n => some (2 + n)
        | none => none
      else none
    else if tag == 0x07 then -- Prim(2 args): tag + prim + child1 + child2
      if offset + 2 ≤ data.length then
        match michelineNodeSize data (offset + 2) with
        | some n1 =>
          if offset + 2 + n1 ≤ data.length then
            match michelineNodeSize data (offset + 2 + n1) with
            | some n2 => some (2 + n1 + n2)
            | none => none
          else none
        | none => none
      else none
    else none
  else none
termination_by data.length - offset

-- Unpack functions for composite types
def unpackPairV (packed : List (Fin 256)) : Option (List (Fin 256) × List (Fin 256)) :=
  match packed with
  | a :: b :: c :: rest =>
    if a.val = 0x05 ∧ b.val = 0x07 ∧ c.val = 0x07 then
      match michelineNodeSize rest 0 with
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
    if a.val = 0x05 ∧ b.val = 0x05 ∧ c.val = 0x05 then some (true, rest)  -- Left
    else if a.val = 0x05 ∧ b.val = 0x05 ∧ c.val = 0x08 then some (false, rest) -- Right
    else none
  | _ => none

def unpackOptionV (packed : List (Fin 256)) : Option (Bool × List (Fin 256)) :=
  match packed with
  | a :: b :: c :: rest =>
    if a.val = 0x05 ∧ b.val = 0x05 ∧ c.val = 0x09 then some (true, rest)  -- Some
    else if a.val = 0x05 ∧ b.val = 0x03 ∧ c.val = 0x06 ∧ rest = [] then some (false, [])  -- None
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
-- Composite roundtrip proofs (left roundtrip)
-- ============================================================

-- Simp lemma to reduce Fin.val on literal constructors
@[simp] private theorem fin_val_mk (n : Nat) (h : n < m) : (⟨n, h⟩ : Fin m).val = n := rfl

theorem unpackOrV_packLeftV (a : List (Fin 256)) :
    unpackOrV (packLeftV a) = some (true, a) := by
  unfold packLeftV encodeLeftM unpackOrV byte; rfl

theorem unpackOrV_packRightV (b : List (Fin 256)) :
    unpackOrV (packRightV b) = some (false, b) := by
  unfold packRightV encodeRightM unpackOrV byte; rfl

theorem unpackOptionV_packSomeV (a : List (Fin 256)) :
    unpackOptionV (packSomeV a) = some (true, a) := by
  unfold packSomeV encodeSomeM unpackOptionV byte; rfl

theorem unpackOptionV_packNoneV :
    unpackOptionV packNoneV = some (false, []) := by
  unfold packNoneV encodeNoneM unpackOptionV byte; rfl

private theorem uint32be_identity (n : Nat) (h : n < 2 ^ 32) :
    (n / 16777216 % 256) * 16777216 + (n / 65536 % 256) * 65536 +
    (n / 256 % 256) * 256 + n % 256 = n := by omega

theorem unpackListV_packListV (items : List (List (Fin 256)))
    (h : items.flatten.length < 2 ^ 32) :
    unpackListV (packListV items) = some items.flatten := by
  have hid := uint32be_identity items.flatten.length h
  simp only [packListV, encodeListM, encodeUint32BE, byte,
             List.cons_append, List.singleton_append, List.nil_append, List.append_assoc]
  simp only [unpackListV, Fin.val_mk, hid, ite_true, and_self]

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
      match decodeUint32BE rest with
      | some (len, payload) =>
        if payload.length = len then some payload else none
      | none => none
    else none
  | _ => none

-- ============================================================
-- Map: Sequence of Elt pairs (tag 0x07 0x04 key value)
-- ============================================================

/-- Micheline Elt node: Prim(2 args, D_Elt=0x04) -/
def encodeEltM (key val : List (Fin 256)) : List (Fin 256) :=
  [byte 0x07, byte 0x04] ++ key ++ val

/-- Micheline Map: Sequence of Elt-encoded entries -/
def encodeMapM (elts : List (List (Fin 256))) : List (Fin 256) :=
  let payload := elts.flatten
  [byte 0x02] ++ encodeUint32BE payload.length ++ payload

def packMapV (elts : List (List (Fin 256))) : List (Fin 256) :=
  [byte 0x05] ++ encodeMapM elts

def unpackMapV (packed : List (Fin 256)) : Option (List (Fin 256)) :=
  -- Binary level identical to list: sequence tag + length + payload
  unpackListV packed

-- ============================================================
-- Set: identical to list at binary level
-- ============================================================

def encodeSetM := @encodeListM
def packSetV := @packListV
def unpackSetV := @unpackListV

-- ============================================================
-- Address: Bytes node (0x0A) with 22-byte binary address
-- ============================================================

def encodeAddressM (addrBytes : List (Fin 256)) : List (Fin 256) :=
  encodeBytesMM addrBytes

def packAddress (addrBytes : List (Fin 256)) : List (Fin 256) :=
  [byte 0x05] ++ encodeAddressM addrBytes

def unpackAddress (packed : List (Fin 256)) : Option (List (Fin 256)) :=
  unpackBytes packed

-- ============================================================
-- Key_hash: Bytes node (0x0A) with 21-byte binary hash
-- ============================================================

def encodeKeyHashM (hashBytes : List (Fin 256)) : List (Fin 256) :=
  encodeBytesMM hashBytes

def packKeyHash (hashBytes : List (Fin 256)) : List (Fin 256) :=
  [byte 0x05] ++ encodeKeyHashM hashBytes

def unpackKeyHash (packed : List (Fin 256)) : Option (List (Fin 256)) :=
  unpackBytes packed

-- ============================================================
-- Key: Bytes node (0x0A) with tag + public key bytes
-- ============================================================

def encodeKeyM (keyBytes : List (Fin 256)) : List (Fin 256) :=
  encodeBytesMM keyBytes

def packKey (keyBytes : List (Fin 256)) : List (Fin 256) :=
  [byte 0x05] ++ encodeKeyM keyBytes

def unpackKey (packed : List (Fin 256)) : Option (List (Fin 256)) :=
  unpackBytes packed

-- ============================================================
-- Signature: Bytes node (0x0A) with raw signature bytes
-- ============================================================

def encodeSignatureM (sigBytes : List (Fin 256)) : List (Fin 256) :=
  encodeBytesMM sigBytes

def packSignature (sigBytes : List (Fin 256)) : List (Fin 256) :=
  [byte 0x05] ++ encodeSignatureM sigBytes

def unpackSignature (packed : List (Fin 256)) : Option (List (Fin 256)) :=
  unpackBytes packed

-- ============================================================
-- Chain_id: Bytes node (0x0A) with 4 raw bytes
-- ============================================================

def encodeChainIdM (idBytes : List (Fin 256)) : List (Fin 256) :=
  encodeBytesMM idBytes

def packChainId (idBytes : List (Fin 256)) : List (Fin 256) :=
  [byte 0x05] ++ encodeChainIdM idBytes

def unpackChainId (packed : List (Fin 256)) : Option (List (Fin 256)) :=
  unpackBytes packed

-- ============================================================
-- Roundtrip proofs for bytes-node types
-- ============================================================

@[simp] theorem unpackBytes_packBytes (data : List (Fin 256)) (hs : data.length < 2^32) :
    unpackBytes (packBytes data) = some data := by
  unfold packBytes unpackBytes encodeBytesMM decodeUint32BE encodeUint32BE byte
  simp only [List.cons_append, List.singleton_append, List.nil_append, List.append_assoc, fin_val_mk]
  have hid := uint32be_identity data.length hs
  simp only [hid, ite_true, and_self]

@[simp] theorem unpackAddress_packAddress (data : List (Fin 256)) (hs : data.length < 2^32) :
    unpackAddress (packAddress data) = some data :=
  unpackBytes_packBytes data hs

@[simp] theorem unpackKeyHash_packKeyHash (data : List (Fin 256)) (hs : data.length < 2^32) :
    unpackKeyHash (packKeyHash data) = some data :=
  unpackBytes_packBytes data hs

@[simp] theorem unpackKey_packKey (data : List (Fin 256)) (hs : data.length < 2^32) :
    unpackKey (packKey data) = some data :=
  unpackBytes_packBytes data hs

@[simp] theorem unpackSignature_packSignature (data : List (Fin 256)) (hs : data.length < 2^32) :
    unpackSignature (packSignature data) = some data :=
  unpackBytes_packBytes data hs

@[simp] theorem unpackChainId_packChainId (data : List (Fin 256)) (hs : data.length < 2^32) :
    unpackChainId (packChainId data) = some data :=
  unpackBytes_packBytes data hs

-- Map/Set roundtrip: delegates to list roundtrip
theorem unpackMapV_packMapV (elts : List (List (Fin 256)))
    (h : elts.flatten.length < 2 ^ 32) :
    unpackMapV (packMapV elts) = some elts.flatten := by
  have hid := uint32be_identity elts.flatten.length h
  simp only [unpackMapV, packMapV, encodeMapM, encodeUint32BE, byte,
             List.cons_append, List.singleton_append, List.nil_append, List.append_assoc]
  simp only [unpackListV, Fin.val_mk, hid, ite_true, and_self]

-- ============================================================
-- Mutez: nat zarith with uint64 overflow check (0 ≤ v ≤ 2^63-1)
-- ============================================================

def packMutez (v : Nat) : List (Fin 256) :=
  [byte 0x05, byte 0x00] ++ encode v

def unpackMutez (bytes : List (Fin 256)) : Option Nat :=
  match unpackNat bytes with
  | some n => if n < 2 ^ 63 then some n else none
  | none => none

-- ============================================================
-- Timestamp: signed int zarith with int64 overflow check
-- ============================================================

def packTimestamp (v : Int) : List (Fin 256) :=
  [byte 0x05, byte 0x00] ++ encodeInt v

def unpackTimestamp (bytes : List (Fin 256)) : Option Int :=
  match unpackInt bytes with
  | some z => if z ≥ -(2 ^ 63 : Int) ∧ z < (2 ^ 63 : Int) then some z else none
  | none => none

-- ============================================================
-- Bool/Unit roundtrip proofs
-- ============================================================

@[simp] theorem unpackBool_packBool (b : Bool) : unpackBool (packBool b) = some b := by
  cases b <;> (unfold packBool unpackBool byte; rfl)

theorem packBool_unpackBool (bs : List (Fin 256)) (b : Bool)
    (h : unpackBool bs = some b) : packBool b = bs := by
  simp only [unpackBool] at h
  match bs with
  | [a, b', c] =>
    simp only at h
    split at h
    · rename_i h1
      obtain ⟨ha, hb, hc⟩ := h1
      simp at h; subst h
      show [byte 0x05, byte 0x03, byte 0x0A] = [a, b', c]
      congr 1; · exact Fin.ext ha.symm
      congr 1; · exact Fin.ext hb.symm
      congr 1; exact Fin.ext hc.symm
    · split at h
      · rename_i h1 h2
        obtain ⟨ha, hb, hc⟩ := h2
        simp at h; subst h
        show [byte 0x05, byte 0x03, byte 0x03] = [a, b', c]
        congr 1; · exact Fin.ext ha.symm
        congr 1; · exact Fin.ext hb.symm
        congr 1; exact Fin.ext hc.symm
      · simp at h
  | [] => simp at h
  | [_] => simp at h
  | [_, _] => simp at h
  | _ :: _ :: _ :: _ :: _ => simp at h

@[simp] theorem unpackUnit_packUnit : unpackUnit packUnit = some () := by
  unfold unpackUnit packUnit byte; rfl

theorem packUnit_unpackUnit (bs : List (Fin 256)) (h : unpackUnit bs = some ()) :
    packUnit = bs := by
  simp only [unpackUnit] at h
  match bs with
  | [a, b, c] =>
    simp only at h
    split at h
    · rename_i h1
      obtain ⟨ha, hb, hc⟩ := h1
      show [byte 0x05, byte 0x03, byte 0x0B] = [a, b, c]
      congr 1; · exact Fin.ext ha.symm
      congr 1; · exact Fin.ext hb.symm
      congr 1; exact Fin.ext hc.symm
    · simp at h
  | [] => simp at h
  | [_] => simp at h
  | [_, _] => simp at h
  | _ :: _ :: _ :: _ :: _ => simp at h

-- ============================================================
-- String roundtrip proofs
-- ============================================================

theorem decodeUint32BE_encodeUint32BE (n : Nat) (hn : n < 2^32)
    (rest : List (Fin 256)) :
    decodeUint32BE (encodeUint32BE n ++ rest) = some (n, rest) := by
  unfold encodeUint32BE decodeUint32BE
  simp only [List.cons_append, fin_val_mk]
  congr 1; congr 1; omega

@[simp] theorem unpackString_packString (s : List (Fin 256)) (hs : s.length < 2^32) :
    unpackString (packString s) = some s := by
  unfold packString unpackString encodeUint32BE decodeUint32BE byte
  simp only [List.cons_append, List.singleton_append, List.nil_append, List.append_assoc, fin_val_mk,
             and_self, ite_true]
  have hid := uint32be_identity s.length hs
  simp only [hid, ite_true]

theorem encodeUint32BE_decodeUint32BE (b0 b1 b2 b3 : Fin 256) :
    encodeUint32BE (b0.val * 16777216 + b1.val * 65536 + b2.val * 256 + b3.val) = [b0, b1, b2, b3] := by
  simp only [encodeUint32BE]
  have h0 := b0.isLt; have h1 := b1.isLt; have h2 := b2.isLt; have h3 := b3.isLt
  congr 1
  · exact Fin.ext (by simp only [fin_val_mk]; omega)
  · congr 1
    · exact Fin.ext (by simp only [fin_val_mk]; omega)
    · congr 1
      · exact Fin.ext (by simp only [fin_val_mk]; omega)
      · congr 1
        · exact Fin.ext (by simp only [fin_val_mk]; omega)

-- No byte validity theorems needed — Fin 256 enforces validity structurally!

-- ============================================================
-- Arithmetic helper
-- ============================================================

private theorem split128 (n : Nat) (shift : Nat) :
    n % 128 * 2 ^ shift + n / 128 * 2 ^ (shift + 7) = n * 2 ^ shift := by
  rw [Nat.pow_add 2 shift 7]
  have h7 : (2 : Nat) ^ 7 = 128 := by decide
  rw [h7, Nat.mul_comm (2 ^ shift) 128,
      ← Nat.mul_assoc (n / 128) 128 (2 ^ shift),
      ← Nat.add_mul (n % 128) (n / 128 * 128) (2 ^ shift)]
  congr 1; omega

-- ============================================================
-- Left roundtrip: decode(encode(n)) = some (n, [])
-- ============================================================

/-- decodeTail inverts encodeTail for positive n -/
theorem decodeTail_encodeTail (n : Nat) (hn : 0 < n) (shift : Nat) :
    decodeTail (encodeTail n) shift = some (n * 2 ^ shift, []) := by
  induction n using Nat.strongRecOn generalizing shift with
  | ind n ih =>
    have hne : ¬(n = 0) := by omega
    unfold encodeTail
    simp only [hne, ite_false]
    split  -- if n < 128
    · -- 0 < n < 128: encodeTail = [⟨n, _⟩]
      rename_i hlt
      simp only [decodeTail, Fin.val_mk, show ¬(n ≥ 128) from by omega, ite_false,
                 show ¬(n = 0) from hne]
    · -- n ≥ 128: encodeTail = ⟨n%128+128, _⟩ :: encodeTail(n/128)
      rename_i hge
      simp only [decodeTail, Fin.val_mk, show n % 128 + 128 ≥ 128 from by omega, ite_true]
      have hdiv_lt : n / 128 < n := Nat.div_lt_self hn (by omega)
      have hdiv_pos : 0 < n / 128 := by omega
      rw [ih (n / 128) hdiv_lt hdiv_pos (shift + 7)]
      show some ((n % 128 + 128) % 128 * 2 ^ shift + n / 128 * 2 ^ (shift + 7), [])
           = some (n * 2 ^ shift, [])
      congr 1; congr 1
      have : (n % 128 + 128) % 128 = n % 128 := by omega
      rw [this]
      exact split128 n shift

/-- Main left roundtrip -/
theorem decode_encode (n : Nat) : decode (encode n) = some (n, []) := by
  unfold encode
  split  -- if n < 64
  · -- n < 64: encode = [⟨n, _⟩]
    rename_i hlt
    simp only [decode, Fin.val_mk, show ¬(n ≥ 128) from by omega, ite_false,
               show ¬(n ≥ 64) from by omega]
  · -- n ≥ 64: encode = ⟨n%64+128, _⟩ :: encodeTail(n/64)
    rename_i hge
    simp only [decode, Fin.val_mk, show n % 64 + 128 ≥ 128 from by omega, ite_true,
               show ¬(n % 64 + 128 ≥ 192) from by omega, ite_false]
    have hdiv_pos : 0 < n / 64 := by omega
    rw [decodeTail_encodeTail (n / 64) hdiv_pos 6]
    show some ((n % 64 + 128) % 64 + n / 64 * 2 ^ 6, []) = some (n, [])
    congr 1; congr 1
    have hmod : (n % 64 + 128) % 64 = n % 64 := by omega
    rw [hmod]
    have h64 : (2 : Nat) ^ 6 = 64 := by decide
    rw [h64]; omega

-- ============================================================
-- Left roundtrip for signed int
-- ============================================================

/-- Left roundtrip for signed int: non-negative case. -/
theorem decodeInt_encodeInt_ofNat (n : Nat) :
    decodeInt (encodeInt (Int.ofNat n)) = some (Int.ofNat n, []) := by
  simp only [encodeInt]
  unfold encode
  by_cases hn : n < 64
  · simp only [hn, dite_true, decodeInt, fin_val_mk, ite_true]
  · simp only [show ¬(n < 64) from hn, dite_false, decodeInt, fin_val_mk]
    have hge : ¬(n % 64 + 128 < 64) := by omega
    have hge2 : ¬(n % 64 + 128 < 128) := by omega
    have hlt3 : n % 64 + 128 < 192 := by omega
    simp only [hge, hge2, hlt3, ite_false, ite_true]
    have hdiv_pos : 0 < n / 64 := by omega
    rw [decodeTail_encodeTail (n / 64) hdiv_pos 6]
    have hmod : (n % 64 + 128) % 64 = n % 64 := by omega
    simp only [hmod]
    apply congrArg (fun x => some (Int.ofNat x, []))
    have h64 : (2 : Nat) ^ 6 = 64 := by decide
    rw [h64]; omega

/-- Left roundtrip for signed int: negative case -/
theorem decodeInt_encodeInt_negSucc (n : Nat) :
    decodeInt (encodeInt (Int.negSucc n)) = some (Int.negSucc n, []) := by
  simp only [encodeInt]
  by_cases hn : n.succ < 64
  · -- Single byte: [⟨n.succ + 64, _⟩]
    simp only [hn, dite_true, decodeInt, fin_val_mk]
    have h1 : ¬(n.succ + 64 < 64) := by omega
    have h2 : n.succ + 64 < 128 := by omega
    simp only [h1, h2, ite_false, ite_true]
    have hne : ¬(n.succ + 64 = 64) := by omega
    simp only [hne, ite_false]
    have hsub : n.succ + 64 - 64 = n.succ := by omega
    simp only [hsub]
    simp [Int.negSucc_eq]
  · -- Multi byte
    simp only [show ¬(n.succ < 64) from hn, dite_false, decodeInt, fin_val_mk]
    have h1 : ¬(n.succ % 64 + 64 + 128 < 64) := by omega
    have h2 : ¬(n.succ % 64 + 64 + 128 < 128) := by omega
    have h3 : ¬(n.succ % 64 + 64 + 128 < 192) := by omega
    simp only [h1, h2, h3, ite_false]
    have hdiv_pos : 0 < n.succ / 64 := by omega
    rw [decodeTail_encodeTail (n.succ / 64) hdiv_pos 6]
    have hmod : (n.succ % 64 + 64 + 128) % 64 = n.succ % 64 := by omega
    simp only [hmod]
    rw [show Int.negSucc n = -Int.ofNat (n + 1) from by simp [Int.negSucc_eq]]
    apply congrArg (fun x => some (-Int.ofNat x, []))
    have h64 : (2 : Nat) ^ 6 = 64 := by decide
    rw [h64]; omega

/-- Left roundtrip for signed int encoding -/
theorem decodeInt_encodeInt (z : Int) : decodeInt (encodeInt z) = some (z, []) := by
  cases z with
  | ofNat n => exact decodeInt_encodeInt_ofNat n
  | negSucc n => exact decodeInt_encodeInt_negSucc n

-- ============================================================
-- Right roundtrip: encode(decode(b)) = b
-- No hbytes precondition needed — Fin 256 enforces byte validity!
-- ============================================================

/-- Key helper: decodeTail produces a value that is m * 2^shift for some m > 0,
    and encodeTail m reconstructs the input bytes. -/
theorem encodeTail_decodeTail (bs : List (Fin 256)) (shift v : Nat) (rem : List (Fin 256))
    (hd : decodeTail bs shift = some (v, rem)) :
    ∃ m, m > 0 ∧ v = m * 2 ^ shift ∧ encodeTail m ++ rem = bs := by
  induction bs generalizing shift v rem with
  | nil => simp [decodeTail] at hd
  | cons b rest ih =>
    simp only [decodeTail] at hd
    by_cases hb : b.val ≥ 128
    · -- Continuation byte: b.val ≥ 128
      simp only [hb, ite_true] at hd
      match hrec : decodeTail rest (shift + 7) with
      | none => simp [hrec] at hd
      | some (rv, rem') =>
        simp [hrec] at hd
        obtain ⟨rfl, rfl⟩ := hd
        obtain ⟨m', hm'pos, hm'eq, hm'enc⟩ := ih (shift + 7) rv rem' hrec
        -- Let m = b.val%128 + m' * 128
        refine ⟨b.val % 128 + m' * 128, by omega, ?_, ?_⟩
        · -- value = m * 2^shift
          rw [hm'eq, Nat.add_mul, Nat.mul_assoc]
          congr 1
          rw [Nat.pow_add]
          have h7 : (2 : Nat) ^ 7 = 128 := by decide
          rw [h7]; congr 1; exact Nat.mul_comm _ _
        · -- encodeTail m ++ rem' = b :: rest
          have hmod : (b.val % 128 + m' * 128) % 128 = b.val % 128 := by omega
          have hdiv : (b.val % 128 + m' * 128) / 128 = m' := by omega
          have hb_lt := b.isLt
          have hb_eq : b.val % 128 + 128 = b.val := by omega
          have hnz : ¬(b.val % 128 + m' * 128 = 0) := by omega
          have hge : ¬(b.val % 128 + m' * 128 < 128) := by omega
          -- Work directly: unfold encodeTail in the goal and simplify
          show encodeTail (b.val % 128 + m' * 128) ++ rem' = b :: rest
          unfold encodeTail
          simp only [hnz, ite_false, dif_neg hge, hmod, hdiv, List.cons_append,
                     List.cons.injEq]
          exact ⟨Fin.ext (by simp [fin_val_mk, hb_eq]), hm'enc⟩
    · -- Final byte: b.val < 128
      simp only [show ¬(b.val ≥ 128) from hb, ite_false] at hd
      by_cases hbz : b.val = 0
      · simp [hbz] at hd
      · simp only [hbz, ite_false] at hd
        obtain ⟨rfl, rfl⟩ := hd
        refine ⟨b.val, by omega, rfl, ?_⟩
        have hlt128 : b.val < 128 := by omega
        show encodeTail b.val ++ rest = b :: rest
        unfold encodeTail
        simp only [hbz, ite_false, dif_pos hlt128, List.singleton_append, List.cons.injEq, and_true,
                   Fin.ext_iff, fin_val_mk]

/-- Right roundtrip for nat: if decode succeeds with no remainder, encode recovers the bytes.
    No hbytes precondition — Fin 256 values are always < 256 by construction. -/
theorem encode_decode (bs : List (Fin 256)) (n : Nat)
    (hd : decode bs = some (n, [])) :
    encode n = bs := by
  match bs, hd with
  | [], hd => simp [decode] at hd
  | first :: rest, hd =>
    simp only [decode] at hd
    by_cases hfirst : first.val ≥ 128
    · -- Multi-byte
      simp only [hfirst, ite_true] at hd
      by_cases hfirst192 : first.val ≥ 192
      · simp [hfirst192] at hd
      · simp only [show ¬(first.val ≥ 192) from hfirst192, ite_false] at hd
        match htail : decodeTail rest 6 with
        | none => simp [htail] at hd
        | some (tv, rem) =>
          simp [htail] at hd
          obtain ⟨rfl, rfl⟩ := hd
          obtain ⟨m, hmpos, hmval, hmenc⟩ :=
            encodeTail_decodeTail rest 6 tv [] htail
          rw [List.append_nil] at hmenc
          have h64 : (2 : Nat) ^ 6 = 64 := by decide
          rw [h64] at hmval
          rw [hmval]
          have hfirst_lt := first.isLt
          have hfirst_eq : first.val % 64 + 128 = first.val := by omega
          have hge : ¬(first.val % 64 + m * 64 < 64) := by omega
          show encode (first.val % 64 + m * 64) = first :: rest
          show encode (first.val % 64 + m * 64) = first :: rest
          unfold encode
          simp only [dif_neg hge]
          have hmod : (first.val % 64 + m * 64) % 64 = first.val % 64 := by omega
          have hdiv : (first.val % 64 + m * 64) / 64 = m := by omega
          simp only [hmod, hdiv, List.cons.injEq]
          exact ⟨Fin.ext (by simp [hfirst_eq]), hmenc⟩
    · -- Single byte
      simp only [show ¬(first.val ≥ 128) from hfirst, ite_false] at hd
      by_cases hfirst64 : first.val ≥ 64
      · simp [hfirst64] at hd
      · simp only [show ¬(first.val ≥ 64) from hfirst64, ite_false] at hd
        have heq := Option.some.inj hd
        have hn : first.val = n := (Prod.mk.inj heq).1
        have hrem : rest = [] := (Prod.mk.inj heq).2
        subst hrem; rw [← hn]
        have hlt : first.val < 64 := by omega
        show encode first.val = [first]
        unfold encode
        simp only [dif_pos hlt, List.cons.injEq, List.nil_eq, and_true, Fin.ext_iff, fin_val_mk]

/-- Right roundtrip for int: if decodeInt succeeds with no remainder, encodeInt recovers the bytes.
    No hbytes precondition — Fin 256 values are always < 256 by construction. -/
theorem encodeInt_decodeInt (bs : List (Fin 256)) (z : Int)
    (hd : decodeInt bs = some (z, [])) :
    encodeInt z = bs := by
  match bs, hd with
  | [], hd => simp [decodeInt] at hd
  | first :: rest, hd =>
    simp only [decodeInt] at hd
    have hfirst_lt := first.isLt
    -- Case 1: first.val < 64 (positive, single byte)
    by_cases h64 : first.val < 64
    · simp only [h64, ite_true] at hd
      have heq := Option.some.inj hd
      have hz : z = Int.ofNat first.val := (Prod.mk.inj heq).1.symm
      have hrem : rest = [] := (Prod.mk.inj heq).2
      subst hz; subst hrem
      show encode first.val = [first]
      unfold encode
      simp only [dif_pos h64, List.cons.injEq, List.nil_eq, and_true, Fin.ext_iff, fin_val_mk]
    · simp only [h64, ite_false] at hd
      -- Case 2: 64 ≤ first.val < 128 (negative, single byte)
      by_cases h128 : first.val < 128
      · simp only [h128, ite_true] at hd
        by_cases h64eq : first.val = 64
        · simp [h64eq] at hd
        · simp only [h64eq, ite_false] at hd
          have heq := Option.some.inj hd
          have hz : z = -Int.ofNat (first.val - 64) := (Prod.mk.inj heq).1.symm
          have hrem : rest = [] := (Prod.mk.inj heq).2
          subst hz; subst hrem
          have hk : first.val - 64 > 0 := by omega
          show encodeInt (-Int.ofNat (first.val - 64)) = [first]
          rw [show -Int.ofNat (first.val - 64) = Int.negSucc (first.val - 64 - 1) from by
            simp [Int.negSucc_eq]; omega]
          simp only [encodeInt]
          have ha : (first.val - 64 - 1) + 1 = first.val - 64 := by omega
          simp only [ha]
          have hlt_64 : first.val - 64 < 64 := by omega
          simp only [dif_pos hlt_64]
          congr 1; exact Fin.ext (by simp [fin_val_mk]; omega)
      · simp only [show ¬(first.val < 128) from h128, ite_false] at hd
        -- Case 3: 128 ≤ first.val < 192 (positive, multi-byte)
        by_cases h192 : first.val < 192
        · simp only [h192, ite_true] at hd
          match htail : decodeTail rest 6 with
          | none => simp [htail] at hd
          | some (tv, rem) =>
            simp [htail] at hd
            obtain ⟨hz, hrem⟩ := hd
            subst hrem; rw [← hz]
            simp only [encodeInt]
            have hdec : decode (first :: rest) = some (first.val % 64 + tv, []) := by
              simp only [decode, show first.val ≥ 128 from by omega, ite_true,
                         show ¬(first.val ≥ 192) from by omega, ite_false, htail]
            exact encode_decode (first :: rest) (first.val % 64 + tv) hdec
        · -- Case 4: first.val ≥ 192 (negative, multi-byte)
          simp only [show ¬(first.val < 192) from h192, ite_false] at hd
          match htail : decodeTail rest 6 with
          | none => simp [htail] at hd
          | some (tv, rem) =>
            simp [htail] at hd
            obtain ⟨hz, hrem⟩ := hd
            subst hrem; rw [← hz]
            obtain ⟨m, hmpos, hmval, hmenc⟩ :=
              encodeTail_decodeTail rest 6 tv [] htail
            rw [List.append_nil] at hmenc
            have h64pow : (2 : Nat) ^ 6 = 64 := by decide
            rw [h64pow] at hmval
            have hk_pos : first.val % 64 + tv > 0 := by omega
            have hneg : -(↑first.val % (64 : Int) + ↑tv) = Int.negSucc (first.val % 64 + tv - 1) := by
              simp [Int.negSucc_eq]; push_cast; omega
            rw [hneg]; simp only [encodeInt]
            have ha : (first.val % 64 + tv - 1) + 1 = first.val % 64 + tv := by omega
            subst hmval
            have hge : ¬(first.val % 64 + m * 64 < 64) := by omega
            have hmod : (first.val % 64 + m * 64) % 64 = first.val % 64 := by omega
            have hdiv : (first.val % 64 + m * 64) / 64 = m := by omega
            have hfirst_eq : first.val % 64 + 64 + 128 = first.val := by omega
            simp only [ha, dif_neg hge, hmod, hdiv, List.cons.injEq]
            exact ⟨Fin.ext (by simp [fin_val_mk, hfirst_eq]), hmenc⟩

-- ============================================================
-- Convenience left roundtrips at pack/unpack level
-- ============================================================

@[simp] theorem unpackNat_packNat (n : Nat) : unpackNat (packNat n) = some n := by
  show (if (⟨0x05, by omega⟩ : Fin 256).val = 0x05 ∧ (⟨0x00, by omega⟩ : Fin 256).val = 0x00 then
    match decode (encode n) with | some (v, []) => some v | _ => none
    else none) = some n
  simp only [fin_val_mk, and_self, ite_true, decode_encode]

@[simp] theorem unpackInt_packInt (z : Int) : unpackInt (packInt z) = some z := by
  show (if (⟨0x05, by omega⟩ : Fin 256).val = 0x05 ∧ (⟨0x00, by omega⟩ : Fin 256).val = 0x00 then
    match decodeInt (encodeInt z) with | some (v, []) => some v | _ => none
    else none) = some z
  simp only [fin_val_mk, and_self, ite_true, decodeInt_encodeInt]

@[simp] theorem unpackMutez_packMutez (v : Nat) (hv : v < 2 ^ 63) :
    unpackMutez (packMutez v) = some v := by
  have h : packMutez v = packNat v := rfl
  simp only [unpackMutez, h, unpackNat_packNat, hv, ite_true]

@[simp] theorem unpackTimestamp_packTimestamp (v : Int) (hge : v ≥ -(2^63 : Int)) (hlt : v < (2^63 : Int)) :
    unpackTimestamp (packTimestamp v) = some v := by
  have h : packTimestamp v = packInt v := rfl
  simp only [unpackTimestamp, h, unpackInt_packInt, hge, hlt, and_self, ite_true]

-- ============================================================
-- Right roundtrip for pack/unpack level (no hbytes!)
-- ============================================================

theorem packNat_unpackNat (bs : List (Fin 256)) (n : Nat)
    (hd : unpackNat bs = some n) :
    packNat n = bs := by
  simp only [unpackNat] at hd
  match bs with
  | first :: second :: rest =>
    simp only at hd
    split at hd
    · rename_i h05
      obtain ⟨hf, hs⟩ := h05
      match hdec : decode rest with
      | some (v, []) =>
        simp [hdec] at hd; subst hd
        have henc := encode_decode rest v hdec
        show [byte 0x05, byte 0x00] ++ encode v = first :: second :: rest
        rw [henc]
        simp only [byte, List.cons_append, List.singleton_append]
        congr 1
        · exact Fin.ext (by simp_all)
        · congr 1; exact Fin.ext (by simp_all)
      | some (_, _ :: _) => simp [hdec] at hd
      | none => simp [hdec] at hd
    · simp at hd
  | [] => simp at hd
  | [_] => simp at hd

theorem packInt_unpackInt (bs : List (Fin 256)) (z : Int)
    (hd : unpackInt bs = some z) :
    packInt z = bs := by
  simp only [unpackInt] at hd
  match bs with
  | first :: second :: rest =>
    simp only at hd
    split at hd
    · rename_i h05
      obtain ⟨hf, hs⟩ := h05
      match hdec : decodeInt rest with
      | some (v, []) =>
        simp [hdec] at hd; subst hd
        have henc := encodeInt_decodeInt rest v hdec
        show [byte 0x05, byte 0x00] ++ encodeInt v = first :: second :: rest
        rw [henc]
        simp only [byte, List.cons_append, List.singleton_append]
        congr 1
        · exact Fin.ext (by simp_all)
        · congr 1; exact Fin.ext (by simp_all)
      | some (_, _ :: _) => simp [hdec] at hd
      | none => simp [hdec] at hd
    · simp at hd
  | [] => simp at hd
  | [_] => simp at hd

end Micheline
