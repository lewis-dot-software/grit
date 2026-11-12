import Shrink.Step

/-!
The model's executable: one request a line on standard input, one answer a line on standard output.

A request is tab-separated: a first failure as its choices joined by commas, then the answers shrinking it is told, in
order, each `1` for a candidate that failed and `0` for one that did not.

An answer is tab-separated: each candidate proposed, in order, written `[1,2]` and run together, then `shrunk` or
`shrinking` for the state the answers leave, then that state's current sequence. The candidates stop where shrinking
ends, though answers are left.

A request of any other shape is answered `refused <request>`.
-/

open Grit

/-- The sequence `cs` written `[1,2]`. -/
def write (cs : Seq) : String := "[" ++ ",".intercalate (cs.map toString) ++ "]"

/-- The number the decimal numeral `s` names, or none where `s` is no decimal numeral. -/
def numeral (s : String) : Option Nat :=
  if !s.isEmpty && s.all Char.isDigit then some s.toNat! else none

/-- The sequence whose choices `s` joins by commas, or none where a choice is no decimal numeral. -/
def readSeq (s : String) : Option Seq :=
  if s.isEmpty then some [] else (s.splitOn ",").mapM numeral

/-- The answers `s` writes as `0` and `1`, or none where it holds anything else. -/
def readAnswers (s : String) : Option (List Bool) :=
  s.toList.mapM fun
    | '0' => some false
    | '1' => some true
    | _ => none

/-- The candidates written so far, then the state `state` comes to told each of `answers` in turn. -/
def replay (written : String) : Shrink → List Bool → String
  | .shrinking s, a :: as => replay (written ++ write s.candidate) (told s a) as
  | .shrinking s, [] => written ++ "\tshrinking\t" ++ write s.current
  | .shrunk current, _ => written ++ "\tshrunk\t" ++ write current

def respond (request : String) : String :=
  match request.splitOn "\t" with
  | [first, answers] =>
    match readSeq first, readAnswers answers with
    | some first, some answers => replay "" (start first) answers
    | _, _ => s!"refused {request}"
  | _ => s!"refused {request}"

partial def serve (stdin : IO.FS.Stream) (stdout : IO.FS.Stream) : IO Unit := do
  let line ← stdin.getLine
  if line.isEmpty then return
  stdout.putStrLn (respond (String.ofList (line.toList.filter (· != '\n'))))
  stdout.flush
  serve stdin stdout

def main : IO Unit := do
  serve (← IO.getStdin) (← IO.getStdout)
