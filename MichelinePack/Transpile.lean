/-
  AST-based Lean 4 → Solidity transpiler using SolStmt/SolExpr IR.

  Pipeline:
    Lean Expr → SolStmt/SolExpr (Lean-specific unwrapping) → String (pretty-printer)

  Works with the recursive (non-monadic) functions in Implementation.lean.

  Key insight: for WF-recursive functions, we use the equation lemma
  (e.g. Implementation.encodeTail.eq_def) to get a clean unfolded body,
  rather than trying to walk the opaque WellFounded.fixF expression.

  Currently transpiles 17 functions from Implementation.lean:
    Zarith core (7):  encodeTail, encode, encodeInt, decodeTail, decode,
                      decodeInt, decodeUint32BE
    Inner encoders (10): encodeNatM, encodeIntM, encodeBoolM, encodePairM,
                         encodeLeftM, encodeRightM, encodeSomeM, encodeEltM,
                         encodeUnitM, encodeNoneM

  Remaining functions stay as hand-written templates because they require:
    - Solidity-specific types (string memory, bytes4) not derivable from Lean
    - For loops (list, _slice) or while loops (_michelineNodeSize)
    - Error types with context args (TrailingBytes, UnexpectedNodeTag)
    - Overflow guards (bytes_, string_) not present in the Lean spec
-/

import MichelinePack.Implementation
import Lean

open Lean Meta Elab

namespace Transpile

-- ============================================================
-- Step 1: SolStmt / SolExpr IR
-- ============================================================

/-- Solidity expression AST -/
inductive SolExpr where
  | num : Nat → SolExpr
  | str : String → SolExpr
  | var : String → SolExpr
  | binop : String → SolExpr → SolExpr → SolExpr
  | unop : String → SolExpr → SolExpr
  | call : String → List SolExpr → SolExpr
  | encodePacked : List SolExpr → SolExpr
  | cast : String → SolExpr → SolExpr  -- uint8(x), uint256(x)
  | index : SolExpr → SolExpr → SolExpr  -- data[i]
  | bytesEmpty : SolExpr  -- new bytes(0) or bytes("")
  | hexLit : String → SolExpr                   -- hex"0500"
  | memberAccess : SolExpr → String → SolExpr   -- x.length
  | arrayIndex : SolExpr → SolExpr → SolExpr    -- x[i] (no uint8 cast)
  | newBytes : SolExpr → SolExpr                 -- new bytes(n)
  | castBytes4 : SolExpr → SolExpr               -- bytes4(uint32(x))
  | typeCast : String → SolExpr → SolExpr        -- string(x), bytes(x)
  | typeMax : String → SolExpr                   -- type(uint32).max
  | shl : SolExpr → Nat → SolExpr               -- x << n
  | bitor : SolExpr → SolExpr → SolExpr          -- x | y
  | castBytes4FromByte : SolExpr → SolExpr        -- bytes4(x) for single byte
  | shrBytes4 : SolExpr → Nat → SolExpr          -- bytes4(x) >> n
deriving Repr, Inhabited

/-- Solidity statement AST -/
inductive SolStmt where
  | ret : SolExpr → SolStmt
  | retEmpty : SolStmt  -- return new bytes(0);
  | revert : String → List SolExpr → SolStmt
  | ite : SolExpr → SolStmt → SolStmt → SolStmt
  | letDecl : String → String → SolExpr → SolStmt  -- type name = expr;
  | assign : String → SolExpr → SolStmt  -- name = expr;
  | seq : List SolStmt → SolStmt
  | comment : String → SolStmt
  | unchecked : SolStmt → SolStmt  -- unchecked { ... }
  | raw : String → SolStmt  -- raw Solidity code (for patterns not in IR)
  | forLoop : String → String → SolExpr → List SolStmt → SolStmt  -- for (uint256 i = 0; i < bound; i++) { body }
  | whileLoop : SolExpr → List SolStmt → SolStmt   -- while (cond) { body }
  | assignIndex : SolExpr → SolExpr → SolExpr → SolStmt  -- arr[i] = val
  | assignField : String → SolExpr → SolStmt       -- name = expr; (for named return vars)
  | retVoid : SolStmt                               -- return; (no value)
  | ifOnly : SolExpr → SolStmt → SolStmt            -- if (cond) { body } (no else)
  | elseIf : SolExpr → SolStmt → SolStmt → SolStmt  -- if (cond) { body } else if/else { ... }
  | varDecl : String → String → SolStmt             -- type name; (no initializer)
deriving Repr, Inhabited

/-- Solidity function definition -/
structure SolFunc where
  name : String
  params : List (String × String)  -- (type, name)
  retType : String
  body : SolStmt
  visibility : String := "private"
  mutability : String := "pure"
  noReturn : Bool := false  -- if true, omit "returns (...)" clause
deriving Repr

-- ============================================================
-- Step 2: Pretty-printer (SolStmt/SolExpr → String)
-- ============================================================

partial def SolExpr.toSol : SolExpr → String
  | .num n => toString n
  | .str s => s!"\"{s}\""
  | .var name => name
  | .binop op a b => s!"({a.toSol} {op} {b.toSol})"
  | .unop op a => s!"{op}({a.toSol})"
  | .call fn args => s!"{fn}({", ".intercalate (args.map toSol)})"
  | .encodePacked args => s!"abi.encodePacked({", ".intercalate (args.map toSol)})"
  | .cast ty e => s!"{ty}({e.toSol})"
  | .index arr idx => s!"{arr.toSol}[{idx.toSol}]"
  | .bytesEmpty => "new bytes(0)"
  | .hexLit s => s!"hex\"{s}\""
  | .memberAccess e field => s!"{e.toSol}.{field}"
  | .arrayIndex arr idx => s!"{arr.toSol}[{idx.toSol}]"
  | .newBytes sz => s!"new bytes({sz.toSol})"
  | .castBytes4 e => s!"bytes4(uint32({e.toSol}))"
  | .typeCast ty e => s!"{ty}({e.toSol})"
  | .typeMax ty => s!"type({ty}).max"
  | .shl e n => s!"{e.toSol} << {n}"
  | .bitor a b => s!"{a.toSol}\n                    | {b.toSol}"
  | .castBytes4FromByte e => s!"bytes4({e.toSol})"
  | .shrBytes4 e n => s!"(bytes4({e.toSol}) >> {n})"

/-- Generate indentation string -/
def indent (n : Nat) : String :=
  "".pushn ' ' (n * 4)

partial def SolStmt.toSol (depth : Nat := 0) : SolStmt → String
  | .ret e => s!"{indent depth}return {e.toSol};"
  | .retEmpty => s!"{indent depth}return new bytes(0);"
  | .revert msg args =>
    let argStr := ", ".intercalate (args.map SolExpr.toSol)
    s!"{indent depth}revert {msg}({argStr});"
  | .ite cond thenBr elseBr =>
    let thenStr := thenBr.toSol (depth + 1)
    let elseStr := elseBr.toSol (depth + 1)
    s!"{indent depth}if ({cond.toSol}) \{\n{thenStr}\n{indent depth}} else \{\n{elseStr}\n{indent depth}}"
  | .letDecl ty name val =>
    s!"{indent depth}{ty} {name} = {val.toSol};"
  | .assign name val =>
    s!"{indent depth}{name} = {val.toSol};"
  | .seq stmts =>
    "\n".intercalate (stmts.map (SolStmt.toSol (depth)))
  | .comment msg =>
    s!"{indent depth}// {msg}"
  | .unchecked body =>
    let bodyStr := body.toSol (depth + 1)
    s!"{indent depth}unchecked \{\n{bodyStr}\n{indent depth}}"
  | .raw code =>
    s!"{indent depth}{code}"
  | .forLoop iVar initVal bound body =>
    let bodyStr := "\n".intercalate (body.map (SolStmt.toSol (depth + 1)))
    s!"{indent depth}for (uint256 {iVar} = {initVal}; {iVar} < {bound.toSol}; {iVar}++) \{\n{bodyStr}\n{indent depth}}"
  | .whileLoop cond body =>
    let bodyStr := "\n".intercalate (body.map (SolStmt.toSol (depth + 1)))
    s!"{indent depth}while ({cond.toSol}) \{\n{bodyStr}\n{indent depth}}"
  | .assignIndex arr idx val =>
    s!"{indent depth}{arr.toSol}[{idx.toSol}] = {val.toSol};"
  | .assignField name val =>
    s!"{indent depth}{name} = {val.toSol};"
  | .retVoid =>
    s!"{indent depth}return;"
  | .ifOnly cond body =>
    let bodyStr := body.toSol (depth + 1)
    s!"{indent depth}if ({cond.toSol}) \{\n{bodyStr}\n{indent depth}}"
  | .elseIf cond thenBr elseBr =>
    let thenStr := thenBr.toSol (depth + 1)
    let elseStr := elseBr.toSol depth  -- same depth for chained else if
    s!"{indent depth}if ({cond.toSol}) \{\n{thenStr}\n{indent depth}} else {elseStr}"
  | .varDecl ty name =>
    s!"{indent depth}{ty} {name};"

/-- Emit a complete Solidity function -/
def emitSolidity (func : SolFunc) : String :=
  let paramStr := func.params.map (fun (ty, n) => s!"{ty} {n}") |> ", ".intercalate
  let bodyStr := func.body.toSol 2
  let retClause := if func.noReturn then "" else s!" returns ({func.retType})"
  s!"    function {func.name}({paramStr}) {func.visibility} {func.mutability}{retClause} \{\n{bodyStr}\n    }"

/-- Check if an expression contains negation of an int cast, which needs unchecked -/
partial def SolExpr.needsUnchecked : SolExpr → Bool
  | .unop "-" (.cast "int256" _) => true
  | .unop "-" e => e.needsUnchecked
  | .binop _ a b => a.needsUnchecked || b.needsUnchecked
  | .call _ args => args.any SolExpr.needsUnchecked
  | .cast _ e => e.needsUnchecked
  | _ => false

/-- Wrap a return statement in unchecked if the expression needs it -/
def wrapRetUnchecked (stmt : SolStmt) : SolStmt :=
  match stmt with
  | .ret e => if e.needsUnchecked then .unchecked (.ret e) else .ret e
  | s => s

-- ============================================================
-- Step 3: Lean Expr → SolExpr / SolStmt translator
-- ============================================================

/-- Variable context: maps de Bruijn indices to variable names -/
abbrev VarCtx := List String

def VarCtx.lookup (ctx : VarCtx) (n : Nat) : String :=
  ctx.getD n s!"_v{n}"

def VarCtx.push (ctx : VarCtx) (name : String) : VarCtx :=
  name :: ctx

/-- Check if needle is a substring of haystack -/
def strContains (haystack needle : String) : Bool :=
  (haystack.splitOn needle).length > 1

/-- Extract a Nat literal, stripping OfNat.ofNat wrappers -/
partial def getNatLit (e : Expr) : Option Nat :=
  match e with
  | .lit (.natVal n) => some n
  | .app (.app (.app (.const ``OfNat.ofNat _) _) n) _ => getNatLit n
  | .app fn _ => getNatLit fn
  | _ => none

/-- Map from Lean function names to Solidity names -/
def solNameMap : List (Name × String) :=
  [ (``Implementation.encodeTail, "_encodeZarithTail")
  , (``Implementation.encode, "_encodeZarithNat")
  , (``Implementation.encodeInt, "_encodeZarithInt")
  , (``Implementation.decodeTail, "_decodeZarithTail")
  , (``Implementation.decode, "_decodeZarithNat")
  , (``Implementation.decodeInt, "_decodeZarithInt")
  , (``Implementation.decodeUint32BE, "_decodeUint32BE")
  -- Inner Micheline encoders (transpiled)
  , (``Implementation.encodeNatM, "nat")
  , (``Implementation.encodeIntM, "int_")
  , (``Implementation.encodeBoolM, "bool_")
  , (``Implementation.encodePairM, "pair")
  , (``Implementation.encodeLeftM, "left")
  , (``Implementation.encodeRightM, "right")
  , (``Implementation.encodeSomeM, "some")
  , (``Implementation.encodeEltM, "elt")
  -- Remaining names (for potential future use in call resolution)
  , (``Implementation.encodeStringM, "string_")
  , (``Implementation.encodeBytesMM, "bytes_")
  ]

def lookupSolName (name : Name) : Option String :=
  (solNameMap.find? (fun (n, _) => n == name)).map (·.2)

mutual

/-- Collect elements from a List.cons chain into a flat list -/
partial def collectListCons (ctx : VarCtx) (e : Expr) : MetaM (Option (List SolExpr)) := do
  let fn := e.getAppFn
  let args := e.getAppArgs
  if let .const name _ := fn then
    if name == ``List.nil then
      return some []
    if name == ``List.cons && args.size >= 3 then
      let headExpr ← exprToSolExpr ctx args[1]!
      match ← collectListCons ctx args[2]! with
      | some tail => return some (headExpr :: tail)
      | none => return none
  return none

/-- Convert a Lean expression to a SolExpr -/
partial def exprToSolExpr (ctx : VarCtx) (e : Expr) : MetaM SolExpr := do
  match e with
  | .lit (.natVal n) => return .num n
  | .bvar idx => return .var (ctx.lookup idx)
  | .fvar id => let decl ← id.getDecl; return .var decl.userName.toString
  | .const name _ =>
    if name == ``List.nil then return .bytesEmpty
    if name == ``Bool.true then return .var "true"
    if name == ``Bool.false then return .var "false"
    return .var name.toString

  | .letE name _ _val body _ =>
    let ctx' := ctx.push name.toString
    exprToSolExpr ctx' body

  | .lam name _ body _ =>
    let ctx' := ctx.push name.toString
    exprToSolExpr ctx' body

  | .app .. =>
    let fn := e.getAppFn
    let args := e.getAppArgs

    -- Nat literal wrapped in OfNat
    if let some n := getNatLit e then
      return .num n

    if let .const name _ := fn then

      -- Fin.mk: extract the value, drop the bound and proof
      if name == ``Fin.mk && args.size >= 3 then
        return ← exprToSolExpr ctx args[1]!

      -- Fin.val / Fin.isLt: extract value from Fin
      if name == ``Fin.val && args.size >= 2 then
        return ← exprToSolExpr ctx args[1]!

      -- Any Fin-related constructor: ⟨n, proof⟩ — strip to just n
      if strContains name.toString "Fin" && args.size >= 2 then
        -- Try to extract a nat literal from the value argument
        if let some n := getNatLit args[1]! then
          return .num n
        return ← exprToSolExpr ctx args[1]!

      -- Arithmetic
      if name == ``HMod.hMod && args.size >= 6 then
        let a ← exprToSolExpr ctx args[4]!
        let b ← exprToSolExpr ctx args[5]!
        return .binop "%" a b
      if name == ``HDiv.hDiv && args.size >= 6 then
        let a ← exprToSolExpr ctx args[4]!
        let b ← exprToSolExpr ctx args[5]!
        return .binop "/" a b
      if name == ``HAdd.hAdd && args.size >= 6 then
        let a ← exprToSolExpr ctx args[4]!
        let b ← exprToSolExpr ctx args[5]!
        return .binop "+" a b
      if name == ``HMul.hMul && args.size >= 6 then
        let a ← exprToSolExpr ctx args[4]!
        let b ← exprToSolExpr ctx args[5]!
        return .binop "*" a b
      if name == ``HPow.hPow && args.size >= 6 then
        let a ← exprToSolExpr ctx args[4]!
        let b ← exprToSolExpr ctx args[5]!
        return .binop "**" a b

      -- List.append (HAppend.hAppend) → abi.encodePacked(a, b)
      -- Flatten nested abi.encodePacked calls
      if name == ``HAppend.hAppend && args.size >= 6 then
        let a ← exprToSolExpr ctx args[4]!
        let b ← exprToSolExpr ctx args[5]!
        let aArgs := match a with | .encodePacked xs => xs | x => [x]
        let bArgs := match b with | .encodePacked xs => xs | x => [x]
        return .encodePacked (aArgs ++ bArgs)

      -- Comparisons
      if name == ``GE.ge && args.size >= 4 then
        let a ← exprToSolExpr ctx args[2]!
        let b ← exprToSolExpr ctx args[3]!
        return .binop ">=" a b
      if name == ``LE.le && args.size >= 4 then
        let a ← exprToSolExpr ctx args[2]!
        let b ← exprToSolExpr ctx args[3]!
        return .binop "<=" a b
      if name == ``LT.lt && args.size >= 4 then
        let a ← exprToSolExpr ctx args[2]!
        let b ← exprToSolExpr ctx args[3]!
        return .binop "<" a b
      if name == ``GT.gt && args.size >= 4 then
        let a ← exprToSolExpr ctx args[2]!
        let b ← exprToSolExpr ctx args[3]!
        return .binop ">" a b
      if name == ``BEq.beq && args.size >= 4 then
        let a ← exprToSolExpr ctx args[2]!
        let b ← exprToSolExpr ctx args[3]!
        -- Simplify: (x == true) → x, (x == false) → !x
        match b with
        | .var "true" => return a
        | .var "false" => return .unop "!" a
        | _ => pure ()
        match a with
        | .var "true" => return b
        | .var "false" => return .unop "!" b
        | _ => pure ()
        return .binop "==" a b
      if name == ``bne && args.size >= 4 then
        let a ← exprToSolExpr ctx args[2]!
        let b ← exprToSolExpr ctx args[3]!
        return .binop "!=" a b
      if name == ``Eq && args.size >= 3 then
        let a ← exprToSolExpr ctx args[1]!
        let b ← exprToSolExpr ctx args[2]!
        -- Simplify: (x == true) → x, (x == false) → !x
        match b with
        | .var "true" => return a
        | .var "false" => return .unop "!" a
        | _ => pure ()
        match a with
        | .var "true" => return b
        | .var "false" => return .unop "!" b
        | _ => pure ()
        return .binop "==" a b

      -- Not
      if name == ``Not && args.size >= 1 then
        let a ← exprToSolExpr ctx args[0]!
        return .unop "!" a

      -- Ne (a ≠ b) → a != b
      if name == ``Ne && args.size >= 3 then
        let a ← exprToSolExpr ctx args[1]!
        let b ← exprToSolExpr ctx args[2]!
        return .binop "!=" a b

      -- Bool.not → ! operator
      if (name == ``Bool.not || name == ``not) && args.size >= 1 then
        let a ← exprToSolExpr ctx args[0]!
        return .unop "!" a

      -- Subtraction (HSub.hSub)
      if name == ``HSub.hSub && args.size >= 6 then
        let a ← exprToSolExpr ctx args[4]!
        let b ← exprToSolExpr ctx args[5]!
        return .binop "-" a b

      -- Negation (Neg.neg): -x
      if name == ``Neg.neg && args.size >= 3 then
        let a ← exprToSolExpr ctx args[args.size - 1]!
        return .unop "-" a

      -- Int.ofNat: cast Nat → int256
      if name == ``Int.ofNat && args.size >= 1 then
        let a ← exprToSolExpr ctx args[0]!
        return .cast "int256" a

      -- getElem (data[offset] with proof): @GetElem.getElem ... data offset proof → uint8(data[offset])
      -- Args: [containerType, indexType, elemType, validPred, instance, container, index, proof]
      if name == ``GetElem.getElem && args.size >= 6 then
        let arr ← exprToSolExpr ctx args[args.size - 3]!
        let idx ← exprToSolExpr ctx args[args.size - 2]!
        return .cast "uint8" (.index arr idx)

      -- List.getD (data.getD offset 0) → uint8(data[offset])
      if name == ``List.getD && args.size >= 4 then
        let arr ← exprToSolExpr ctx args[1]!
        let idx ← exprToSolExpr ctx args[2]!
        return .cast "uint8" (.index arr idx)

      -- List.length → data.length
      if name == ``List.length && args.size >= 2 then
        let arr ← exprToSolExpr ctx args[1]!
        return .var s!"{arr.toSol}.length"

      -- Decide: unwrap
      if name == ``decide || name == ``Decidable.decide then
        return ← exprToSolExpr ctx args[0]!

      -- List.cons: build abi.encodePacked
      if name == ``List.cons && args.size >= 3 then
        match ← collectListCons ctx e with
        | some elems =>
          let castElems := elems.map fun el => SolExpr.cast "uint8" el
          return .encodePacked castElems
        | none =>
          let head ← exprToSolExpr ctx args[1]!
          let tail ← exprToSolExpr ctx args[2]!
          return .encodePacked [.cast "uint8" head, tail]

      -- Special case: encodeUint32BE n → bytes4(uint32(n))
      -- The Lean encoder returns [b0, b1, b2, b3] but in Solidity we use
      -- bytes4(uint32(n)) which is the idiomatic big-endian encoding.
      if name == ``Implementation.encodeUint32BE && args.size >= 1 then
        let arg ← exprToSolExpr ctx args[args.size - 1]!
        return .cast "bytes4" (.cast "uint32" arg)

      -- Known Implementation functions → recursive call with Solidity name
      if let some solName := lookupSolName name then
        -- Look up arity from solNameMap configs to take only the right args
        let arity := match solNameMap.find? (fun (n, _) => n == name) with
          | some _ =>
            -- Use the known arities for each function
            if name == ``Implementation.encodeTail then 1
            else if name == ``Implementation.encode then 1
            else if name == ``Implementation.encodeInt then 1
            else if name == ``Implementation.decodeTail then 3
            else if name == ``Implementation.decode then 2
            else if name == ``Implementation.decodeInt then 2
            else if name == ``Implementation.decodeUint32BE then 2
            -- Inner encoders
            else if name == ``Implementation.encodeNatM then 1
            else if name == ``Implementation.encodeIntM then 1
            else if name == ``Implementation.encodeBoolM then 1
            else if name == ``Implementation.encodeStringM then 1
            else if name == ``Implementation.encodeBytesMM then 1
            else if name == ``Implementation.encodePairM then 2
            else if name == ``Implementation.encodeLeftM then 1
            else if name == ``Implementation.encodeRightM then 1
            else if name == ``Implementation.encodeSomeM then 1
            else if name == ``Implementation.encodeEltM then 2
            else args.size
          | none => args.size
        let relevantArgs := args.toList.drop (args.size - arity)
        let argExprs ← relevantArgs.mapM (exprToSolExpr ctx)
        return .call solName argExprs

      -- Prod.mk → return tuple-like
      if name == ``Prod.mk && args.size >= 4 then
        let a ← exprToSolExpr ctx args[2]!
        let b ← exprToSolExpr ctx args[3]!
        return .call "" [a, b]  -- will be rendered as (a, b)

      -- Proof terms / Fin constructors: if name contains "_proof" or "Fin", strip
      if strContains name.toString "_proof" || strContains name.toString ".proof" then
        -- This is a proof term — return a dummy (shouldn't appear in output)
        return .num 0

      -- Fallback: emit as variable reference
      if args.isEmpty then
        return .var name.getString!

      -- Generic function call fallback
      -- Filter out proof arguments (any arg whose string repr contains "_proof")
      let argExprs ← args.toList.mapM (exprToSolExpr ctx)
      let filtered := argExprs.filter fun e => !strContains e.toSol "_proof"
      if filtered.length < argExprs.length then
        -- Had proof args — this is likely a Fin constructor, return the first non-proof arg
        match filtered with
        | [val] => return val
        | val :: _ => return val
        | [] => return .num 0
      return .call name.getString! argExprs

    -- Non-const function application
    let fnExpr ← exprToSolExpr ctx fn
    let argExprs ← args.toList.mapM (exprToSolExpr ctx)
    return .call fnExpr.toSol argExprs

  | _ =>
    let pp ← ppExpr e
    return .var s!"/* {pp} */"

/-- Convert a Lean expression to a SolStmt -/
partial def exprToSolStmt (ctx : VarCtx) (e : Expr) : MetaM SolStmt := do
  match e with
  -- Let binding → local variable declaration + rest
  | .letE name _ val body _ =>
    let nameStr := name.toString
    -- Skip compiler-generated names
    if nameStr.startsWith "_" then
      let ctx' := ctx.push nameStr
      return ← exprToSolStmt ctx' body
    let valExpr ← exprToSolExpr ctx val
    let ctx' := ctx.push nameStr
    let bodyStmt ← exprToSolStmt ctx' body
    return .seq [.letDecl "uint256" nameStr valExpr, bodyStmt]

  -- Lambda (unwrap)
  | .lam name _ body _ =>
    let ctx' := ctx.push name.toString
    return ← exprToSolStmt ctx' body

  | .app .. =>
    let fn := e.getAppFn
    let args := e.getAppArgs

    if let .const name _ := fn then

      -- ite / dite → SolStmt.ite
      if (name == ``ite || name == ``dite) && args.size >= 5 then
        let condExpr ← exprToSolExpr ctx args[1]!
        let thenStmt ← exprToSolStmt ctx args[3]!
        let elseStmt ← exprToSolStmt ctx args[4]!
        return .ite condExpr thenStmt elseStmt

      -- List.cons at statement level → return abi.encodePacked(...)
      if name == ``List.cons && args.size >= 3 then
        match ← collectListCons ctx e with
        | some elems =>
          let castElems := elems.map fun el => SolExpr.cast "uint8" el
          return .ret (.encodePacked castElems)
        | none =>
          let head ← exprToSolExpr ctx args[1]!
          let tail ← exprToSolExpr ctx args[2]!
          return .ret (.encodePacked [.cast "uint8" head, tail])

      -- List.nil → return empty bytes
      if name == ``List.nil then
        return .retEmpty

      -- Option.none → revert
      if name == ``Option.none then
        return .revert "InvalidEncoding" []
      -- Option.some → return the value
      if name == ``Option.some && args.size >= 2 then
        let val ← exprToSolExpr ctx args[args.size - 1]!
        return wrapRetUnchecked (.ret val)

      -- Except.error → revert with specific error
      if name == ``Except.error && args.size >= 3 then
        let errArg := args[args.size - 1]!
        let errName := match errArg.getAppFn with
          | .const n _ =>
            if n == ``Implementation.DecodeError.inputTruncated then "InputTruncated"
            else if n == ``Implementation.DecodeError.natNegative then "NatNegative"
            else if n == ``Implementation.DecodeError.negativeZero then "NegativeZero"
            else if n == ``Implementation.DecodeError.trailingZeroByte then "TrailingZeroByte"
            else if n == ``Implementation.DecodeError.trailingBytes then "TrailingBytes"
            else if n == ``Implementation.DecodeError.intOverflow then "IntOverflow"
            else if n == ``Implementation.DecodeError.invalidVersionByte then "InvalidVersionByte"
            else if n == ``Implementation.DecodeError.unexpectedNodeTag then "UnexpectedNodeTag"
            else if n == ``Implementation.DecodeError.invalidBoolTag then "InvalidBoolTag"
            else "InvalidEncoding"
          | _ => "InvalidEncoding"
        return .revert errName []
      -- Except.ok → return the value
      if name == ``Except.ok && args.size >= 3 then
        let val ← exprToSolExpr ctx args[args.size - 1]!
        return wrapRetUnchecked (.ret val)

      -- Prod.mk → return tuple
      if name == ``Prod.mk && args.size >= 4 then
        let a ← exprToSolExpr ctx args[2]!
        let b ← exprToSolExpr ctx args[3]!
        return wrapRetUnchecked (.ret (.call "" [a, b]))

      -- match_ with 4 args: could be Int match, Option match, or Except match on decoder result
      if strContains name.toString "match_" && args.size == 4 then
        let target := args[1]!
        let handler2 := args[2]!  -- noneHandler (Option) / ofNatHandler (Int) / errorHandler (Except)
        let handler3 := args[3]!  -- someHandler (Option) / negSuccHandler (Int) / okHandler (Except)

        -- Check if this is an Option match: handler2 is `fun _ => none`
        let isOptionMatch := match handler2 with
          | .lam _ _ body _ =>
            let bodyFn := body.getAppFn
            match bodyFn with
            | .const n _ => n == ``Option.none
            | _ => false
          | _ => false

        -- Check if this is an Except match: handler2 is `fun e => Except.error e`
        let isExceptMatch := match handler2 with
          | .lam _ _ body _ =>
            let bodyFn := body.getAppFn
            match bodyFn with
            | .const n _ => n == ``Except.error
            | _ => false
          | _ => false

        if isOptionMatch then
          -- Option match on a function call (e.g., match decodeTail ... with | none => none | some (rv, newOff) => ...)
          -- The discriminee is a function call that returns (value, newOffset).
          -- In Solidity: (uint256 rv, uint256 newOff) = _func(...);
          -- The none case is implicit (the called function reverts on failure).
          let callExpr ← exprToSolExpr ctx target
          -- handler3 is: fun rv => fun newOff => some(body)
          -- or: fun rv newOff => some(body)
          -- We need to peel the lambdas to get the variable names and body
          match handler3 with
          | .lam n1 _ body1 _ =>
            let n1Str := n1.toString
            match body1 with
            | .lam n2 _ body2 _ =>
              let n2Str := n2.toString
              -- De Bruijn: in `fun rv => fun newOff => body`, bvar 0 = newOff, bvar 1 = rv
              let ctx' := (ctx.push n1Str).push n2Str
              -- Determine type from the function being called
              let retType := if strContains name.toString "Int" then "int256" else "uint256"
              let bodyStmt ← exprToSolStmt ctx' body2
              return .seq [
                .raw s!"({retType} {n1Str}, uint256 {n2Str}) = {callExpr.toSol};",
                bodyStmt
              ]
            | _ =>
              -- Single lambda: just bind the result
              let ctx' := ctx.push n1Str
              let bodyStmt ← exprToSolStmt ctx' body1
              return .seq [.letDecl "uint256" n1Str callExpr, bodyStmt]
          | _ =>
            -- Fallback: just emit the some handler
            return ← exprToSolStmt ctx handler3
        else if isExceptMatch then
          -- Except match on a function call (e.g., match decodeTail ... with | .error e => .error e | .ok (rv, newOff) => ...)
          -- The error handler propagates the error, which in Solidity is implicit (called function reverts).
          -- We only need to handle the ok case.
          let callExpr ← exprToSolExpr ctx target
          -- handler3 is the ok handler: fun rv => fun newOff => .ok(body)
          match handler3 with
          | .lam n1 _ body1 _ =>
            let n1Str := n1.toString
            match body1 with
            | .lam n2 _ body2 _ =>
              let n2Str := n2.toString
              let ctx' := (ctx.push n1Str).push n2Str
              let retType := if strContains name.toString "Int" then "int256" else "uint256"
              let bodyStmt ← exprToSolStmt ctx' body2
              return .seq [
                .raw s!"({retType} {n1Str}, uint256 {n2Str}) = {callExpr.toSol};",
                bodyStmt
              ]
            | _ =>
              let ctx' := ctx.push n1Str
              let bodyStmt ← exprToSolStmt ctx' body1
              return .seq [.letDecl "uint256" n1Str callExpr, bodyStmt]
          | _ =>
            return ← exprToSolStmt ctx handler3
        else
          -- Int match (generated match_ with 4 args: motive, target, ofNat, negSucc)
          if handler2.isLambda && handler3.isLambda then
            let targetExpr ← exprToSolExpr ctx target
            -- ofNat handler: fun n => body, where n = uint256(target)
            let ofNatStmt ← match handler2 with
              | .lam n _ body _ =>
                let nStr := n.toString
                let ctx' := ctx.push nStr
                let bodyStmt ← exprToSolStmt ctx' body
                pure (.seq [.letDecl "uint256" nStr (.cast "uint256" targetExpr), bodyStmt])
              | _ => exprToSolStmt ctx handler2
            -- negSucc handler: fun n => body, where Int.negSucc n = -(n+1)
            let negSuccStmt ← match handler3 with
              | .lam n _ body _ =>
                let nStr := n.toString
                let ctx' := ctx.push nStr
                let bodyStmt ← exprToSolStmt ctx' body
                pure (.unchecked (.seq [
                  .letDecl "uint256" nStr
                    (.binop "-" (.cast "uint256" (.unop "-" targetExpr)) (.num 1)),
                  bodyStmt
                ]))
              | _ => exprToSolStmt ctx handler3
            return .ite (.binop ">=" targetExpr (.num 0)) ofNatStmt negSuccStmt

      -- match on Option/generic: translate to last branch (fallback)
      if strContains name.toString "match_" then
        if args.size >= 2 then
          let lastArg := args[args.size - 1]!
          return ← exprToSolStmt ctx lastArg

      -- WellFounded / fix: extract the body
      if strContains name.toString "WellFounded" || strContains name.toString "fix" then
        if args.size > 0 then
          let lastArg := args[args.size - 1]!
          return ← exprToSolStmt ctx lastArg

      -- Default: treat as return of expression
      let expr ← exprToSolExpr ctx e
      return .ret expr

    -- Non-const application
    let expr ← exprToSolExpr ctx e
    return .ret expr

  -- Bare constant
  | .const name _ =>
    if name == ``List.nil then return .retEmpty
    if name == ``Option.none then return .revert "InvalidEncoding" []
    return .ret (.var name.getString!)

  -- Fallback
  | _ =>
    let expr ← exprToSolExpr ctx e
    return .ret expr

end -- mutual

-- ============================================================
-- Step 4: Top-level transpiler using equation lemmas
-- ============================================================

/-- Configuration for a function to transpile -/
structure FuncConfig where
  leanName : Name
  solName : String
  params : List (String × String)
  retType : String
  visibility : String := "private"
  mutability : String := "pure"

/-- Get the unfolded equation body for a function.
    For WF-recursive functions, this gives a clean ite/match expression
    instead of the opaque WellFounded.fixF body.
    For non-recursive functions, falls back to info.value. -/
def getUnfoldedBody (name : Name) : MetaM Expr := do
  let env ← getEnv
  -- Try the equation lemma first (name.eq_def or name.eq_1)
  let eqDefName := name ++ `eq_def
  if let some eqInfo := env.find? eqDefName then
    -- The equation lemma has type: f x₁ ... xₙ = body
    -- We want to extract the RHS
    let eqType := eqInfo.type
    -- forallTelescope to get past the universally-quantified arguments
    forallTelescope eqType fun fvars body => do
      -- body should be: f x₁ ... xₙ = rhs
      if let some (_, _, rhs) := body.eq? then
        -- Abstract back over the fvars to get λ x₁ ... xₙ => rhs
        mkLambdaFVars fvars rhs
      else
        throwError s!"equation lemma {eqDefName} doesn't have expected shape"
  else
    -- Fall back to the raw definition value
    match env.find? name with
    | some (.defnInfo info) => return info.value
    | _ => throwError s!"{name} not found"

/-- Strip leading lambda binders from an expression, collecting their names.
    Used to peel off the function parameters before transpiling the body. -/
private def peelLambdas : Expr → List String → (List String × Expr)
  | .lam name _ body _, acc => peelLambdas body (acc ++ [name.toString])
  | e, acc => (acc, e)

/-- Transpile a named Lean definition to a SolFunc -/
def transpileFunc (config : FuncConfig) : MetaM SolFunc := do
  let body ← getUnfoldedBody config.leanName
  -- Peel leading lambdas and map them to Solidity parameter names
  let (leanParamNames, innerBody) := peelLambdas body []
  -- Build initial context: map each Lean param name to the corresponding
  -- Solidity parameter name from the config.  Since de Bruijn indices
  -- count from the innermost binder, we reverse the list.
  let solParamNames := config.params.map (·.2)
  let ctx : VarCtx := (List.range leanParamNames.length).reverse.map fun i =>
    solParamNames.getD i (leanParamNames.getD i s!"_p{i}")
  let solBody ← exprToSolStmt ctx innerBody
  return {
    name := config.solName
    params := config.params
    retType := config.retType
    body := solBody
    visibility := config.visibility
    mutability := config.mutability
  }

/-- Transpile and pretty-print a function -/
def transpileAndEmit (config : FuncConfig) : MetaM String := do
  let func ← transpileFunc config
  return emitSolidity func

-- ============================================================
-- Step 5: Encoder configurations
-- ============================================================

def encodeTailConfig : FuncConfig :=
  { leanName := ``Implementation.encodeTail
    solName := "_encodeZarithTail"
    params := [("uint256", "rest")]
    retType := "bytes memory" }

def encodeNatConfig : FuncConfig :=
  { leanName := ``Implementation.encode
    solName := "_encodeZarithNat"
    params := [("uint256", "n")]
    retType := "bytes memory" }

def encodeIntConfig : FuncConfig :=
  { leanName := ``Implementation.encodeInt
    solName := "_encodeZarithInt"
    params := [("int256", "z")]
    retType := "bytes memory" }

-- ============================================================
-- Step 5b: Decoder configurations
-- ============================================================

def decodeTailConfig : FuncConfig :=
  { leanName := ``Implementation.decodeTail
    solName := "_decodeZarithTail"
    params := [("bytes memory", "data"), ("uint256", "offset"), ("uint256", "shift")]
    retType := "uint256 value, uint256 newOffset" }

def decodeNatConfig : FuncConfig :=
  { leanName := ``Implementation.decode
    solName := "_decodeZarithNat"
    params := [("bytes memory", "data"), ("uint256", "offset")]
    retType := "uint256 value, uint256 newOffset" }

def decodeIntConfig : FuncConfig :=
  { leanName := ``Implementation.decodeInt
    solName := "_decodeZarithInt"
    params := [("bytes memory", "data"), ("uint256", "offset")]
    retType := "int256 value, uint256 newOffset" }

def decodeUint32BEConfig : FuncConfig :=
  { leanName := ``Implementation.decodeUint32BE
    solName := "_decodeUint32BE"
    params := [("bytes memory", "data"), ("uint256", "offset")]
    retType := "uint256 value, uint256 newOffset" }

-- ============================================================
-- Step 5c: Inner Micheline encoder configurations
-- ============================================================

def encodeNatMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeNatM
    solName := "nat"
    params := [("uint256", "n")]
    retType := "bytes memory"
    visibility := "internal" }

def encodeIntMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeIntM
    solName := "int_"
    params := [("int256", "v")]
    retType := "bytes memory"
    visibility := "internal" }

def encodeBoolMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeBoolM
    solName := "bool_"
    params := [("bool", "v")]
    retType := "bytes memory"
    visibility := "internal" }

def encodePairMConfig : FuncConfig :=
  { leanName := ``Implementation.encodePairM
    solName := "pair"
    params := [("bytes memory", "a"), ("bytes memory", "b")]
    retType := "bytes memory"
    visibility := "internal" }

def encodeLeftMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeLeftM
    solName := "left"
    params := [("bytes memory", "a")]
    retType := "bytes memory"
    visibility := "internal" }

def encodeRightMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeRightM
    solName := "right"
    params := [("bytes memory", "b")]
    retType := "bytes memory"
    visibility := "internal" }

def encodeSomeMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeSomeM
    solName := "some"
    params := [("bytes memory", "a")]
    retType := "bytes memory"
    visibility := "internal" }

def encodeEltMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeEltM
    solName := "elt"
    params := [("bytes memory", "k"), ("bytes memory", "v")]
    retType := "bytes memory"
    visibility := "internal" }

def encodeUnitMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeUnitM
    solName := "unit_"
    params := []
    retType := "bytes memory"
    visibility := "internal" }

def encodeNoneMConfig : FuncConfig :=
  { leanName := ``Implementation.encodeNoneM
    solName := "none"
    params := []
    retType := "bytes memory"
    visibility := "internal" }

-- ============================================================
-- Step 6: Header and IR-constructed functions
-- ============================================================

/-- SPDX header, pragma, library declaration, and error definitions -/
def solHeader : String :=
  "// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Auto-generated from verified Lean 4 specification via AST-based transpiler.
/// @dev Encodes/decodes Michelson PACK format.
///      Verified properties (in Lean 4, zero sorry):
///        - decode(encode(x)) = x   (left roundtrip)
///        - encode(decode(b)) = b   (right roundtrip, for canonical b)
///      API: MichelsonSpec.nat(42) builds raw Micheline, MichelsonSpec.pack(...) adds 0x05.
///
///      All functions are generated from the SolStmt IR (AST-transpiled or IR-constructed).
library MichelsonSpec {

    error InvalidVersionByte(uint8 got);
    error UnexpectedNodeTag(uint8 expected, uint8 got);
    error IntOverflow();
    error NatNegative();
    error NegativeZero();
    error TrailingZeroByte();
    error TrailingBytes(uint256 consumed, uint256 total);
    error InputTruncated();
    error InvalidBoolTag(uint8 got);
    error InvalidEncoding();
"

-- ============================================================
-- IR-constructed wrapper/encoder functions
-- ============================================================

-- Helper: micheline.length
private def michelineLen : SolExpr := .memberAccess (.var "micheline") "length"
-- Helper: uint8(micheline[i])
private def michelineByte (i : SolExpr) : SolExpr := .cast "uint8" (.arrayIndex (.var "micheline") i)
-- Helper: uint8(data[i])
private def dataByte (i : SolExpr) : SolExpr := .cast "uint8" (.arrayIndex (.var "data") i)

/-- pack(micheline): return abi.encodePacked(hex"05", micheline) -/
def irPackFn : SolFunc := {
  name := "pack"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.encodePacked [.hexLit "05", .var "micheline"])
}

/-- unpack(packed): strip 0x05 prefix -/
def irUnpackFn : SolFunc := {
  name := "unpack"
  params := [("bytes memory", "packed")]
  retType := "bytes memory"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" (.memberAccess (.var "packed") "length") (.num 1))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (.cast "uint8" (.arrayIndex (.var "packed") (.num 0))) (.var "0x05"))
      (.revert "InvalidVersionByte" [.cast "uint8" (.arrayIndex (.var "packed") (.num 0))]),
    .ret (.call "_slice" [.var "packed", .num 1,
      .binop "-" (.memberAccess (.var "packed") "length") (.num 1)])
  ]
}

/-- string_(s): encode string as Micheline -/
def irStringFn : SolFunc := {
  name := "string_"
  params := [("string memory", "s")]
  retType := "bytes memory"
  visibility := "internal"
  body := .seq [
    .letDecl "bytes memory" "raw" (.typeCast "bytes" (.var "s")),
    .ifOnly (.binop ">" (.memberAccess (.var "raw") "length") (.typeMax "uint32"))
      (.revert "IntOverflow" []),
    .ret (.encodePacked [.hexLit "01",
      .castBytes4 (.memberAccess (.var "raw") "length"), .var "raw"])
  ]
}

/-- bytes_(data): encode bytes as Micheline Bytes node -/
def irBytesFn : SolFunc := {
  name := "bytes_"
  params := [("bytes memory", "data")]
  retType := "bytes memory"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop ">" (.memberAccess (.var "data") "length") (.typeMax "uint32"))
      (.revert "IntOverflow" []),
    .ret (.encodePacked [.hexLit "0a",
      .castBytes4 (.memberAccess (.var "data") "length"), .var "data"])
  ]
}

/-- list(items): encode list from inner Micheline items (two-pass, O(n)) -/
def irListFn : SolFunc := {
  name := "list"
  params := [("bytes[] memory", "items")]
  retType := "bytes memory"
  visibility := "internal"
  body := .seq [
    -- Pass 1: compute total length
    .letDecl "uint256" "totalLen" (.num 0),
    .forLoop "i" "0" (.memberAccess (.var "items") "length") [
      .assign "totalLen" (.binop "+" (.var "totalLen")
        (.memberAccess (.arrayIndex (.var "items") (.var "i")) "length"))
    ],
    -- Pass 2: copy items into pre-allocated buffer
    .letDecl "bytes memory" "payload" (.newBytes (.var "totalLen")),
    .letDecl "uint256" "offset" (.num 0),
    .forLoop "i" "0" (.memberAccess (.var "items") "length") [
      .letDecl "uint256" "itemLen"
        (.memberAccess (.arrayIndex (.var "items") (.var "i")) "length"),
      .forLoop "j" "0" (.var "itemLen") [
        .assignIndex (.var "payload") (.binop "+" (.var "offset") (.var "j"))
          (.arrayIndex (.arrayIndex (.var "items") (.var "i")) (.var "j"))
      ],
      .assign "offset" (.binop "+" (.var "offset") (.var "itemLen"))
    ],
    .ret (.encodePacked [.hexLit "02",
      .castBytes4 (.var "totalLen"), .var "payload"])
  ]
}

/-- map(elts): delegate to list -/
def irMapFn : SolFunc := {
  name := "map"
  params := [("bytes[] memory", "elts")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "list" [.var "elts"])
}

/-- set(items): delegate to list -/
def irSetFn : SolFunc := {
  name := "set"
  params := [("bytes[] memory", "items")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "list" [.var "items"])
}

/-- address_(addr): delegate to bytes_ -/
def irAddressFn : SolFunc := {
  name := "address_"
  params := [("bytes memory", "addr")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "bytes_" [.var "addr"])
}

/-- keyHash(kh): delegate to bytes_ -/
def irKeyHashFn : SolFunc := {
  name := "keyHash"
  params := [("bytes memory", "kh")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "bytes_" [.var "kh"])
}

/-- key(k): delegate to bytes_ -/
def irKeyFn : SolFunc := {
  name := "key"
  params := [("bytes memory", "k")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "bytes_" [.var "k"])
}

/-- signature_(sig): delegate to bytes_ -/
def irSignatureFn : SolFunc := {
  name := "signature_"
  params := [("bytes memory", "sig")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "bytes_" [.var "sig"])
}

/-- chainId(id): encode chain_id as Micheline Bytes node -/
def irChainIdFn : SolFunc := {
  name := "chainId"
  params := [("bytes4", "id")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.encodePacked [.hexLit "0a", .castBytes4 (.num 4), .var "id"])
}

/-- contract_(addr, ep): encode contract as Micheline Bytes node -/
def irContractFn : SolFunc := {
  name := "contract_"
  params := [("bytes memory", "addr"), ("string memory", "ep")]
  retType := "bytes memory"
  visibility := "internal"
  body := .seq [
    .letDecl "bytes memory" "epBytes" (.typeCast "bytes" (.var "ep")),
    .ite (.binop "==" (.memberAccess (.var "epBytes") "length") (.num 0))
      (.ret (.call "bytes_" [.var "addr"]))
      (.seq [
        .letDecl "bytes memory" "combined" (.encodePacked [.var "addr", .var "epBytes"]),
        .ret (.call "bytes_" [.var "combined"])
      ])
  ]
}

-- ============================================================
-- IR-constructed decoder functions
-- ============================================================

-- Helper: decodeUint32BE as inline expression from 4 bytes at indices 1..4
-- uint256(uint8(arr[1])) << 24 | uint256(uint8(arr[2])) << 16 | ...
private def decodeLen32 (arr : String) : SolExpr :=
  .bitor
    (.bitor
      (.bitor
        (.shl (.cast "uint256" (.cast "uint8" (.arrayIndex (.var arr) (.num 1)))) 24)
        (.shl (.cast "uint256" (.cast "uint8" (.arrayIndex (.var arr) (.num 2)))) 16))
      (.shl (.cast "uint256" (.cast "uint8" (.arrayIndex (.var arr) (.num 3)))) 8))
    (.cast "uint256" (.cast "uint8" (.arrayIndex (.var arr) (.num 4))))

-- Helper: decodeLen32 at offset expressions
private def decodeLen32Off (arr : String) (base : SolExpr) : SolExpr :=
  .bitor
    (.bitor
      (.bitor
        (.shl (.cast "uint256" (.cast "uint8" (.arrayIndex (.var arr) (.binop "+" base (.num 1))))) 24)
        (.shl (.cast "uint256" (.cast "uint8" (.arrayIndex (.var arr) (.binop "+" base (.num 2))))) 16))
      (.shl (.cast "uint256" (.cast "uint8" (.arrayIndex (.var arr) (.binop "+" base (.num 3))))) 8))
    (.cast "uint256" (.cast "uint8" (.arrayIndex (.var arr) (.binop "+" base (.num 4)))))

/-- toNat(micheline): decode raw Micheline to nat -/
def irToNatFn : SolFunc := {
  name := "toNat"
  params := [("bytes memory", "micheline")]
  retType := "uint256"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" michelineLen (.num 2))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x00"))
      (.revert "UnexpectedNodeTag" [.var "0x00", michelineByte (.num 0)]),
    .raw "(uint256 value, uint256 consumed) = _decodeZarithNat(micheline, 1);",
    .ifOnly (.binop "!=" (.var "consumed") michelineLen)
      (.revert "TrailingBytes" [.var "consumed", michelineLen]),
    .ret (.var "value")
  ]
}

/-- toInt(micheline): decode raw Micheline to signed int -/
def irToIntFn : SolFunc := {
  name := "toInt"
  params := [("bytes memory", "micheline")]
  retType := "int256"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" michelineLen (.num 2))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x00"))
      (.revert "UnexpectedNodeTag" [.var "0x00", michelineByte (.num 0)]),
    .raw "(int256 value, uint256 consumed) = _decodeZarithInt(micheline, 1);",
    .ifOnly (.binop "!=" (.var "consumed") michelineLen)
      (.revert "TrailingBytes" [.var "consumed", michelineLen]),
    .ret (.var "value")
  ]
}

/-- toBool(micheline): decode raw Micheline to bool -/
def irToBoolFn : SolFunc := {
  name := "toBool"
  params := [("bytes memory", "micheline")]
  retType := "bool"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "!=" michelineLen (.num 2))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x03"))
      (.revert "UnexpectedNodeTag" [.var "0x03", michelineByte (.num 0)]),
    .letDecl "uint8" "tag" (michelineByte (.num 1)),
    .ifOnly (.binop "==" (.var "tag") (.var "0x0A"))
      (.ret (.var "true")),
    .ifOnly (.binop "==" (.var "tag") (.var "0x03"))
      (.ret (.var "false")),
    .revert "InvalidBoolTag" [.var "tag"]
  ]
}

/-- toUnit(micheline): validate raw Micheline as unit (no return value) -/
def irToUnitFn : SolFunc := {
  name := "toUnit"
  params := [("bytes memory", "micheline")]
  retType := ""
  visibility := "internal"
  noReturn := true
  body := .seq [
    .ifOnly (.binop "!=" michelineLen (.num 2))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x03"))
      (.revert "UnexpectedNodeTag" [.var "0x03", michelineByte (.num 0)]),
    .ifOnly (.binop "!=" (michelineByte (.num 1)) (.var "0x0B"))
      (.revert "UnexpectedNodeTag" [.var "0x0B", michelineByte (.num 1)])
  ]
}

/-- toString(micheline): decode raw Micheline to string -/
def irToStringFn : SolFunc := {
  name := "toString"
  params := [("bytes memory", "micheline")]
  retType := "string memory"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" michelineLen (.num 5))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x01"))
      (.revert "UnexpectedNodeTag" [.var "0x01", michelineByte (.num 0)]),
    .letDecl "uint256" "len" (decodeLen32 "micheline"),
    .ifOnly (.binop "!=" michelineLen (.binop "+" (.num 5) (.var "len")))
      (.revert "TrailingBytes" [.binop "+" (.num 5) (.var "len"), michelineLen]),
    .ret (.typeCast "string" (.call "_slice" [.var "micheline", .num 5, .var "len"]))
  ]
}

/-- toBytes(micheline): decode raw Micheline Bytes node to raw bytes -/
def irToBytesFn : SolFunc := {
  name := "toBytes"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" michelineLen (.num 5))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x0A"))
      (.revert "UnexpectedNodeTag" [.var "0x0A", michelineByte (.num 0)]),
    .letDecl "uint256" "len" (decodeLen32 "micheline"),
    .ifOnly (.binop "!=" michelineLen (.binop "+" (.num 5) (.var "len")))
      (.revert "TrailingBytes" [.binop "+" (.num 5) (.var "len"), michelineLen]),
    .ret (.call "_slice" [.var "micheline", .num 5, .var "len"])
  ]
}

/-- toMutez(micheline): decode Micheline to mutez (bounded nat) -/
def irToMutezFn : SolFunc := {
  name := "toMutez"
  params := [("bytes memory", "micheline")]
  retType := "uint64"
  visibility := "internal"
  body := .seq [
    .letDecl "uint256" "value" (.call "toNat" [.var "micheline"]),
    .ifOnly (.binop ">" (.var "value") (.binop "/" (.typeMax "uint64") (.num 2)))
      (.revert "IntOverflow" []),
    .ret (.cast "uint64" (.var "value"))
  ]
}

/-- toTimestamp(micheline): decode Micheline to timestamp (bounded int) -/
def irToTimestampFn : SolFunc := {
  name := "toTimestamp"
  params := [("bytes memory", "micheline")]
  retType := "int64"
  visibility := "internal"
  body := .seq [
    .letDecl "int256" "value" (.call "toInt" [.var "micheline"]),
    .ifOnly (.binop "||" (.binop "<" (.var "value") (.var "type(int64).min"))
                         (.binop ">" (.var "value") (.var "type(int64).max")))
      (.revert "IntOverflow" []),
    .ret (.cast "int64" (.var "value"))
  ]
}

/-- toPair(micheline): decode Micheline pair into two inner values -/
def irToPairFn : SolFunc := {
  name := "toPair"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory a, bytes memory b"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" michelineLen (.num 3))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x07"))
      (.revert "UnexpectedNodeTag" [.var "0x07", michelineByte (.num 0)]),
    .ifOnly (.binop "!=" (michelineByte (.num 1)) (.var "0x07"))
      (.revert "UnexpectedNodeTag" [.var "0x07", michelineByte (.num 1)]),
    .letDecl "uint256" "child1Size" (.call "_michelineNodeSize" [.var "micheline", .num 2, .num 0]),
    .assignField "a" (.call "_slice" [.var "micheline", .num 2, .var "child1Size"]),
    .assignField "b" (.call "_slice" [.var "micheline",
      .binop "+" (.num 2) (.var "child1Size"),
      .binop "-" (.binop "-" michelineLen (.num 2)) (.var "child1Size")])
  ]
}

/-- toOr(micheline): decode Micheline or into (isLeft, value) -/
def irToOrFn : SolFunc := {
  name := "toOr"
  params := [("bytes memory", "micheline")]
  retType := "bool isLeft, bytes memory value"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" michelineLen (.num 3))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x05"))
      (.revert "UnexpectedNodeTag" [.var "0x05", michelineByte (.num 0)]),
    .letDecl "uint8" "primTag" (michelineByte (.num 1)),
    .elseIf (.binop "==" (.var "primTag") (.var "0x05"))
      (.assignField "isLeft" (.var "true"))
      (.elseIf (.binop "==" (.var "primTag") (.var "0x08"))
        (.assignField "isLeft" (.var "false"))
        (.seq [.revert "UnexpectedNodeTag" [.var "0x05", .var "primTag"]])),
    .assignField "value" (.call "_slice" [.var "micheline", .num 2,
      .binop "-" michelineLen (.num 2)])
  ]
}

/-- toOption(micheline): decode Micheline option into (isSome, value) -/
def irToOptionFn : SolFunc := {
  name := "toOption"
  params := [("bytes memory", "micheline")]
  retType := "bool isSome, bytes memory value"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" michelineLen (.num 2))
      (.revert "InputTruncated" []),
    .letDecl "uint8" "nodeTag" (michelineByte (.num 0)),
    .elseIf (.binop "==" (.var "nodeTag") (.var "0x05"))
      (.seq [
        .ifOnly (.binop "<" michelineLen (.num 3))
          (.revert "InputTruncated" []),
        .ifOnly (.binop "!=" (michelineByte (.num 1)) (.var "0x09"))
          (.revert "UnexpectedNodeTag" [.var "0x09", michelineByte (.num 1)]),
        .assignField "isSome" (.var "true"),
        .assignField "value" (.call "_slice" [.var "micheline", .num 2,
          .binop "-" michelineLen (.num 2)])
      ])
      (.elseIf (.binop "==" (.var "nodeTag") (.var "0x03"))
        (.seq [
          .ifOnly (.binop "!=" (michelineByte (.num 1)) (.var "0x06"))
            (.revert "UnexpectedNodeTag" [.var "0x06", michelineByte (.num 1)]),
          .assignField "isSome" (.var "false"),
          .assignField "value" (.newBytes (.num 0))
        ])
        (.seq [.revert "UnexpectedNodeTag" [.var "0x05", .var "nodeTag"]]))
  ]
}

/-- toList(micheline): decode Micheline list, returns raw payload -/
def irToListFn : SolFunc := {
  name := "toList"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory payload"
  visibility := "internal"
  body := .seq [
    .ifOnly (.binop "<" michelineLen (.num 5))
      (.revert "InputTruncated" []),
    .ifOnly (.binop "!=" (michelineByte (.num 0)) (.var "0x02"))
      (.revert "UnexpectedNodeTag" [.var "0x02", michelineByte (.num 0)]),
    .letDecl "uint256" "len" (decodeLen32 "micheline"),
    .ifOnly (.binop "!=" michelineLen (.binop "+" (.num 5) (.var "len")))
      (.revert "TrailingBytes" [.binop "+" (.num 5) (.var "len"), michelineLen]),
    .assignField "payload" (.call "_slice" [.var "micheline", .num 5, .var "len"])
  ]
}

/-- toMap(micheline): delegate to toList -/
def irToMapFn : SolFunc := {
  name := "toMap"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "toList" [.var "micheline"])
}

/-- toSet(micheline): delegate to toList -/
def irToSetFn : SolFunc := {
  name := "toSet"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "toList" [.var "micheline"])
}

/-- toAddress(micheline): delegate to toBytes -/
def irToAddressFn : SolFunc := {
  name := "toAddress"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "toBytes" [.var "micheline"])
}

/-- toKeyHash(micheline): delegate to toBytes -/
def irToKeyHashFn : SolFunc := {
  name := "toKeyHash"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "toBytes" [.var "micheline"])
}

/-- toKey(micheline): delegate to toBytes -/
def irToKeyFn : SolFunc := {
  name := "toKey"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "toBytes" [.var "micheline"])
}

/-- toSignature(micheline): delegate to toBytes -/
def irToSignatureFn : SolFunc := {
  name := "toSignature"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory"
  visibility := "internal"
  body := .ret (.call "toBytes" [.var "micheline"])
}

/-- toChainId(micheline): decode Micheline Bytes to chain_id -/
def irToChainIdFn : SolFunc := {
  name := "toChainId"
  params := [("bytes memory", "micheline")]
  retType := "bytes4"
  visibility := "internal"
  body := .seq [
    .letDecl "bytes memory" "data" (.call "toBytes" [.var "micheline"]),
    .ifOnly (.binop "!=" (.memberAccess (.var "data") "length") (.num 4))
      (.revert "TrailingBytes" [.num 4, .memberAccess (.var "data") "length"]),
    .ret (.bitor
      (.bitor
        (.bitor
          (.castBytes4FromByte (.arrayIndex (.var "data") (.num 0)))
          (.shrBytes4 (.arrayIndex (.var "data") (.num 1)) 8))
        (.shrBytes4 (.arrayIndex (.var "data") (.num 2)) 16))
      (.shrBytes4 (.arrayIndex (.var "data") (.num 3)) 24))
  ]
}

/-- toContract(micheline): decode Micheline Bytes to contract (address + entrypoint) -/
def irToContractFn : SolFunc := {
  name := "toContract"
  params := [("bytes memory", "micheline")]
  retType := "bytes memory addr, bytes memory entrypoint"
  visibility := "internal"
  body := .seq [
    .letDecl "bytes memory" "data" (.call "toBytes" [.var "micheline"]),
    .comment "Binary address is 22 bytes; anything after is the entrypoint name",
    .ite (.binop "<" (.memberAccess (.var "data") "length") (.num 22))
      (.seq [
        .assignField "addr" (.var "data"),
        .assignField "entrypoint" (.newBytes (.num 0))
      ])
      (.seq [
        .assignField "addr" (.call "_slice" [.var "data", .num 0, .num 22]),
        .assignField "entrypoint" (.call "_slice" [.var "data", .num 22,
          .binop "-" (.memberAccess (.var "data") "length") (.num 22)])
      ])
  ]
}

-- ============================================================
-- IR-constructed internal helpers
-- ============================================================

/-- _michelineNodeSize(data, offset, depth): parse one Micheline node, return size -/
def irMichelineNodeSizeFn : SolFunc := {
  name := "_michelineNodeSize"
  params := [("bytes memory", "data"), ("uint256", "offset"), ("uint256", "depth")]
  retType := "uint256"
  body := .seq [
    .ifOnly (.binop ">" (.var "depth") (.num 64))
      (.revert "InputTruncated" []),
    .ifOnly (.binop ">=" (.var "offset") (.memberAccess (.var "data") "length"))
      (.revert "InputTruncated" []),
    .letDecl "uint8" "tag" (dataByte (.var "offset")),
    .elseIf (.binop "==" (.var "tag") (.var "0x00"))
      -- zarith: scan forward until byte < 128
      (.seq [
        .letDecl "uint256" "i" (.binop "+" (.var "offset") (.num 1)),
        .whileLoop (.binop "<" (.var "i") (.memberAccess (.var "data") "length")) [
          .ifOnly (.binop "<" (dataByte (.var "i")) (.num 128))
            (.ret (.binop "+" (.binop "-" (.var "i") (.var "offset")) (.num 1))),
          .assign "i" (.binop "+" (.var "i") (.num 1))
        ],
        .revert "InputTruncated" []
      ])
      (.elseIf (.binop "||" (.binop "||" (.binop "==" (.var "tag") (.var "0x01"))
                                         (.binop "==" (.var "tag") (.var "0x02")))
                             (.binop "==" (.var "tag") (.var "0x0A")))
        -- length-prefixed node
        (.seq [
          .ifOnly (.binop ">" (.binop "+" (.var "offset") (.num 5))
                              (.memberAccess (.var "data") "length"))
            (.revert "InputTruncated" []),
          .letDecl "uint256" "len" (decodeLen32Off "data" (.var "offset")),
          .ifOnly (.binop ">" (.binop "+" (.binop "+" (.var "offset") (.num 5)) (.var "len"))
                              (.memberAccess (.var "data") "length"))
            (.revert "InputTruncated" []),
          .ret (.binop "+" (.num 5) (.var "len"))
        ])
        (.elseIf (.binop "==" (.var "tag") (.var "0x03"))
          -- prim 0-arg: 2 bytes
          (.ret (.num 2))
          (.elseIf (.binop "==" (.var "tag") (.var "0x05"))
            -- prim 1-arg: 2 + child
            (.seq [
              .letDecl "uint256" "childSize"
                (.call "_michelineNodeSize" [.var "data",
                  .binop "+" (.var "offset") (.num 2),
                  .binop "+" (.var "depth") (.num 1)]),
              .ret (.binop "+" (.num 2) (.var "childSize"))
            ])
            (.elseIf (.binop "==" (.var "tag") (.var "0x07"))
              -- prim 2-arg: 2 + child1 + child2
              (.seq [
                .letDecl "uint256" "child1Size"
                  (.call "_michelineNodeSize" [.var "data",
                    .binop "+" (.var "offset") (.num 2),
                    .binop "+" (.var "depth") (.num 1)]),
                .letDecl "uint256" "child2Size"
                  (.call "_michelineNodeSize" [.var "data",
                    .binop "+" (.binop "+" (.var "offset") (.num 2)) (.var "child1Size"),
                    .binop "+" (.var "depth") (.num 1)]),
                .ret (.binop "+" (.binop "+" (.num 2) (.var "child1Size")) (.var "child2Size"))
              ])
              (.seq [.revert "InputTruncated" []])))))
  ]
}

/-- _slice(data, start, len): copy a slice of bytes -/
def irSliceFn : SolFunc := {
  name := "_slice"
  params := [("bytes memory", "data"), ("uint256", "start"), ("uint256", "len")]
  retType := "bytes memory result"
  body := .seq [
    .assignField "result" (.newBytes (.var "len")),
    .forLoop "i" "0" (.var "len") [
      .assignIndex (.var "result") (.var "i")
        (.arrayIndex (.var "data") (.binop "+" (.var "start") (.var "i")))
    ]
  ]
}

/-- All IR-constructed functions in the order they should appear -/
def irFunctions : List SolFunc :=
  [ irPackFn, irUnpackFn, irStringFn, irBytesFn
  , irListFn, irMapFn, irSetFn
  , irAddressFn, irKeyHashFn, irKeyFn, irSignatureFn
  , irChainIdFn, irContractFn
  -- decoders
  , irToNatFn, irToIntFn, irToBoolFn, irToUnitFn
  , irToStringFn, irToBytesFn
  , irToMutezFn, irToTimestampFn
  , irToPairFn, irToOrFn, irToOptionFn
  , irToListFn, irToMapFn, irToSetFn
  , irToAddressFn, irToKeyHashFn, irToKeyFn, irToSignatureFn
  , irToChainIdFn, irToContractFn
  -- helpers
  , irMichelineNodeSizeFn, irSliceFn
  ]

-- ============================================================
-- Step 7: Full library assembly
-- ============================================================

/-- Transpile encoder and decoder functions and assemble the complete
    MichelsonSpec.sol library.  Runs in MetaM because the transpiler
    needs access to the Lean environment (equation lemmas). -/
def emitFullLibrary : MetaM String := do
  -- Zarith core (transpiled from Lean AST)
  let encTail ← transpileAndEmit encodeTailConfig
  let encNat  ← transpileAndEmit encodeNatConfig
  let encInt  ← transpileAndEmit encodeIntConfig
  let decTail ← transpileAndEmit decodeTailConfig
  let decNat  ← transpileAndEmit decodeNatConfig
  let decInt  ← transpileAndEmit decodeIntConfig
  let decU32  ← transpileAndEmit decodeUint32BEConfig
  -- Inner Micheline encoders (transpiled from Lean AST)
  let mNat    ← transpileAndEmit encodeNatMConfig
  let mInt    ← transpileAndEmit encodeIntMConfig
  let mBool   ← transpileAndEmit encodeBoolMConfig
  let mPair   ← transpileAndEmit encodePairMConfig
  let mLeft   ← transpileAndEmit encodeLeftMConfig
  let mRight  ← transpileAndEmit encodeRightMConfig
  let mSome   ← transpileAndEmit encodeSomeMConfig
  let mElt    ← transpileAndEmit encodeEltMConfig
  let mUnit   ← transpileAndEmit encodeUnitMConfig
  let mNone   ← transpileAndEmit encodeNoneMConfig
  -- IR-constructed functions
  let irBodies := irFunctions.map emitSolidity |>.map (· ++ "\n")
  let irSection := "\n".intercalate irBodies
  return s!"{solHeader}
    // ================================================================
    // [transpiled] Zarith encoders — generated from Lean 4 equation lemmas
    // ================================================================

{encTail}

{encNat}

{encInt}

    // ================================================================
    // [transpiled] Zarith decoders — generated from Lean 4 equation lemmas
    // ================================================================

{decTail}

{decNat}

{decInt}

{decU32}

    // ================================================================
    // [transpiled] Inner Micheline encoders — generated from Lean 4 definitions
    // ================================================================

{mNat}

{mInt}

{mBool}

{mPair}

{mLeft}

{mRight}

{mSome}

{mElt}

{mUnit}

{mNone}

    // ================================================================
    // [IR] Encoding wrappers, decoders, helpers — constructed from SolStmt IR
    // ================================================================

{irSection}}\n"

-- ============================================================
-- Step 8: Generate library at build time
-- ============================================================

/-- Path where the transpiled library is written.
    Writes directly to the sol-test source directory. -/
def generatedLibraryPath : System.FilePath :=
  "sol-test" / "src" / "MichelsonSpec.sol"

#eval show MetaM _ from do
  let lib ← emitFullLibrary
  -- Write to both locations: relative (works from project root) and .lake/build (fallback)
  let fallbackPath : System.FilePath := ".lake" / "build" / "MichelsonSpec_generated.sol"
  IO.FS.writeFile fallbackPath lib
  -- Try the relative path (may fail if CWD is not lean-test/)
  try
    IO.FS.writeFile generatedLibraryPath lib
    IO.println s!"[transpiler] wrote {generatedLibraryPath} ({lib.length} chars)"
  catch _ =>
    IO.println s!"[transpiler] wrote {fallbackPath} ({lib.length} chars)"
    IO.println s!"[transpiler] copy to sol-test/src/MichelsonSpec.sol manually"

end Transpile
