import MichelinePack

/-- Format a list of byte values as hex string -/
def toHex (bytes : List Nat) : String :=
  let hexDigit (n : Nat) : Char :=
    if n < 10 then Char.ofNat (48 + n) else Char.ofNat (87 + n)
  let byteToHex (b : Nat) : String :=
    String.ofList [hexDigit (b / 16), hexDigit (b % 16)]
  String.join (bytes.map byteToHex)

/-- Parse a hex string to list of byte values -/
def fromHex (s : String) : Option (List Nat) :=
  let hexVal (c : Char) : Option Nat :=
    if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
    else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
    else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
    else none
  let chars := s.toList
  -- strip optional "0x" prefix
  let chars := if chars.take 2 == ['0', 'x'] then chars.drop 2 else chars
  if chars.length % 2 ≠ 0 then none
  else
    let rec go : List Char → Option (List Nat)
      | [] => some []
      | c1 :: c2 :: rest => do
        let h ← hexVal c1
        let l ← hexVal c2
        let tail ← go rest
        some ((h * 16 + l) :: tail)
      | [_] => none
    go chars

def usage : String :=
  "Usage:\n  lake exe michelinepack encode <nat>\n  lake exe michelinepack decode <hex>\n  lake exe michelinepack emit"

def main (args : List String) : IO UInt32 := do
  match args with
  | ["encode", nStr] =>
    match nStr.toNat? with
    | some n =>
      let packed := (Micheline.encode n).map Fin.val
      let fullPacked := [0x05, 0x00] ++ packed  -- PACK prefix
      IO.println s!"zarith:  {toHex packed}"
      IO.println s!"packed:  {toHex fullPacked}"
      return 0
    | none =>
      IO.eprintln s!"Error: '{nStr}' is not a valid natural number"
      return 1
  | ["decode", hexStr] =>
    match fromHex hexStr with
    | some bytes =>
      let finBytes : List (Fin 256) := bytes.map (fun b => ⟨b % 256, by omega⟩)
      -- Try full PACK format first (0x05 0x00 prefix)
      match bytes with
      | 0x05 :: 0x00 :: zarithBytes =>
        let finZarith : List (Fin 256) := zarithBytes.map (fun b => ⟨b % 256, by omega⟩)
        match Micheline.decode finZarith with
        | some (n, []) => do IO.println s!"{n}"; return 0
        | some (_, _) => IO.eprintln "Error: trailing bytes"; return 1
        | none => IO.eprintln "Error: invalid zarith encoding"; return 1
      | _ =>
        -- Try raw zarith bytes
        match Micheline.decode finBytes with
        | some (n, []) => do IO.println s!"{n}"; return 0
        | some (_, _) => IO.eprintln "Error: trailing bytes"; return 1
        | none => IO.eprintln "Error: invalid encoding (expected 0500 prefix or raw zarith)"; return 1
    | none =>
      IO.eprintln s!"Error: '{hexStr}' is not valid hex"
      return 1
  | ["emit"] =>
    -- Read the transpiler-generated library (written at build time by Transpile.lean)
    let lib ← IO.FS.readFile Transpile.generatedLibraryPath
    IO.print lib
    return 0
  | _ =>
    IO.eprintln usage
    return 1
