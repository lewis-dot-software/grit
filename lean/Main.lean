import Shrink.Step

/-!
The model's executable: one request a line on standard input, one answer a line on standard output.

A request is tab-separated: a first failure as its choices joined by commas, then the spans its run made, then each
answer shrinking it is told, in order. A span is its start, width and depth joined by colons, and spans are joined by
commas. An answer is `0` for a candidate that did not fail, and `1/` then the spans its run made for one that did.

An answer is tab-separated: each candidate told an answer, in order, written `[1,2]` and run together, then `shrunk` or
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

/-- The span whose start, width and depth `s` joins by colons, or none where it holds anything else. -/
def readSpan (s : String) : Option Span :=
  match (s.splitOn ":").mapM numeral with
  | some [start, width, depth] => some ⟨start, width, depth⟩
  | _ => none

/-- The spans `s` joins by commas, or none where one is no span. -/
def readSpans (s : String) : Option (List Span) :=
  if s.isEmpty then some [] else (s.splitOn ",").mapM readSpan

/-- The answer `s` writes, or none where it is neither `0` nor `1/` then spans. -/
def readAnswer (s : String) : Option Answer :=
  match s.splitOn "/" with
  | ["0"] => some .notFailing
  | ["1", spans] => (readSpans spans).map .failing
  | _ => none

/-- The candidates `written` so far, then each `state` proposes from there told each of `answers` in turn, then the
state those answers leave. -/
def replay (written : String) (state : Shrink) (answers : List Answer) : String :=
  match state, answers with
  | .shrinking s, a :: rest => replay (written ++ write s.candidate) (told s a) rest
  | .shrinking s, [] => written ++ "\tshrinking\t" ++ write s.current
  | .shrunk current, _ => written ++ "\tshrunk\t" ++ write current

/-- The answer to `request`. -/
def respond (request : String) : String :=
  match request.splitOn "\t" with
  | first :: spans :: answers =>
    match readSeq first, readSpans spans, answers.mapM readAnswer with
    | some first, some spans, some answers => replay "" (start first spans) answers
    | _, _, _ => s!"refused {request}"
  | _ => s!"refused {request}"

/-- Answers each line of `stdin` on `stdout`, until `stdin` ends. -/
partial def serve (stdin : IO.FS.Stream) (stdout : IO.FS.Stream) : IO Unit := do
  let line ← stdin.getLine
  if line.isEmpty then return
  stdout.putStrLn (respond (String.ofList (line.toList.filter (· != '\n'))))
  stdout.flush
  serve stdin stdout

def main : IO Unit := do
  serve (← IO.getStdin) (← IO.getStdout)
