import Shrink.Sequence

/-!
The passes: each a function from the current sequence, and the spans its run made, to its candidates, in a fixed
order, as the Dart's `Pass` proposes them.
-/

namespace Grit

/-- One way of proposing smaller sequences. -/
inductive Pass where
  | deleteSpan
  | liftSpan
  | zeroSpan
  | lowerChoice
  | lowerTogether
  | reorder
  | swapSpan
  | moveValue
  deriving DecidableEq, Repr

/-- The passes a round takes after `p`, in order. -/
def Pass.later (p : Pass) : List Pass :=
  match p with
  | .deleteSpan => [.liftSpan, .zeroSpan, .lowerChoice, .lowerTogether, .reorder, .swapSpan, .moveValue]
  | .liftSpan => [.zeroSpan, .lowerChoice, .lowerTogether, .reorder, .swapSpan, .moveValue]
  | .zeroSpan => [.lowerChoice, .lowerTogether, .reorder, .swapSpan, .moveValue]
  | .lowerChoice => [.lowerTogether, .reorder, .swapSpan, .moveValue]
  | .lowerTogether => [.reorder, .swapSpan, .moveValue]
  | .reorder => [.swapSpan, .moveValue]
  | .swapSpan => [.moveValue]
  | .moveValue => []

/-- Every pass, in the order a round takes them. -/
def Pass.all : List Pass := .deleteSpan :: Pass.deleteSpan.later

/-- The widths of span the passes take, the widest first. -/
def widths : List Nat := [8, 4, 3, 2, 1]

/-- Each start of a span of `width` within `length` choices, from the end back. -/
def startsBack (length width : Nat) : List Nat :=
  if width ≤ length then (List.range (length - width + 1)).reverse else []

/-- Each first place of two choices `apart` places apart within `length` choices, from the first on. -/
def pairsFrom (length apart : Nat) : List Nat :=
  (List.range length).filter (· + apart < length)

/-- The probes past 0 of a binary search over the pairs of choices from `low` up to below `pair`, both choices of
each pair halfway from `low` to `pair`, then on from just above it. -/
def halving (pair low : Nat) : List Nat :=
  if low < pair then
    let middle := low + (pair - low) / 2
    (2 * middle - 1) :: 2 * middle :: halving pair (middle + 1)
  else []
termination_by pair - low

/-- The values below `value` a binary search for the smallest failing value probes where every probe passes, over the
pairs of choices an integer's zigzag puts at one distance: 0, then both choices of the pair halfway from just above the
last pair probed to `value`'s own, and last the other choice of `value`'s pair where that is below it. -/
def probes (value : Nat) : List Nat :=
  if value = 0 then []
  else 0 :: halving (value - value / 2) 1 ++ (if value % 2 = 0 then [value - 1] else [])

/-- The choice at `i` of `cs`, or 0 where `cs` holds none there. -/
def choiceAt (cs : Seq) (i : Nat) : Nat := cs.getD i 0

/-- The choices of `cs` that `span` holds. -/
def slice (cs : Seq) (span : Span) : Seq := (cs.drop span.start).take span.width

/-- The spans of `spans` beneath a draw at `depth` that they follow: each deeper than `depth`, up to the first that is
not. -/
def beneath (depth : Nat) (spans : List Span) : List Span :=
  match spans with
  | [] => []
  | s :: rest => if depth < s.depth then s :: beneath depth rest else []

/-- The siblings of a draw at `depth` among the spans of `spans` that follow it: each at `depth`, up to the first
shallower than it. -/
def siblings (depth : Nat) (spans : List Span) : List Span :=
  match spans with
  | [] => []
  | s :: rest =>
    if s.depth < depth then []
    else if s.depth = depth then s :: siblings depth rest
    else siblings depth rest

/-- Each span of 8, 4, 3, 2 or 1 choices deleted, the widest first and each width from the end back, each deletion
followed by the same with the choice before the span lowered by 1, where that choice is above 0. -/
def deleteSpans (cs : Seq) : List Seq :=
  widths.flatMap fun width => (startsBack cs.length width).flatMap fun start =>
    (cs.take start ++ cs.drop (start + width)) ::
      if start > 0 ∧ choiceAt cs (start - 1) > 0 then
        [cs.take (start - 1) ++ [choiceAt cs (start - 1) - 1] ++ cs.drop (start + width)]
      else []

/-- Each draw's span of `spans` replaced by the span of each draw beneath it, the draws taken in the order they
began. -/
def liftSpans (cs : Seq) (spans : List Span) : List Seq :=
  match spans with
  | [] => []
  | outer :: rest =>
    (beneath outer.depth rest).map (fun inner =>
      cs.take outer.start ++ slice cs inner ++ cs.drop (outer.start + outer.width)) ++
      liftSpans cs rest

/-- Each span of 8, 4, 3, 2 or 1 choices set to 0, the spans in the order `deleteSpans` takes them. -/
def zeroSpans (cs : Seq) : List Seq :=
  widths.flatMap fun width => (startsBack cs.length width).map fun start =>
    cs.take start ++ List.replicate width 0 ++ cs.drop (start + width)

/-- Each choice, from the first, lowered to each of its `probes`. -/
def lowerChoices (cs : Seq) : List Seq :=
  (List.range cs.length).flatMap fun i => (probes (choiceAt cs i)).map fun lowered => cs.set i lowered

/-- Each two choices 8, 4, 3, 2 or 1 apart, the farthest apart first, lowered by the same amount: the smaller of the
two to each of its `probes`, and the other by as much. -/
def lowerTogethers (cs : Seq) : List Seq :=
  widths.flatMap fun apart => (pairsFrom cs.length apart).flatMap fun i =>
    let j := i + apart
    let first := choiceAt cs i
    let second := choiceAt cs j
    let least := min first second
    (probes least).map fun lowered =>
      let by_ := least - lowered
      (cs.set i (first - by_)).set j (second - by_)

/-- Each span of 8, 4, 3 or 2 choices sorted, then each two choices 8, 4, 3 or 2 apart swapped, each from the end
back. -/
def reorders (cs : Seq) : List Seq :=
  ((widths.filter (· > 1)).flatMap fun width => (startsBack cs.length width).map fun start =>
    cs.take start ++ ((cs.drop start).take width).mergeSort ++ cs.drop (start + width)) ++
  ((widths.filter (· > 1)).flatMap fun apart => (startsBack cs.length (apart + 1)).map fun i =>
    (cs.set i (choiceAt cs (i + apart))).set (i + apart) (choiceAt cs i))

/-- Each two sibling draws' spans of `spans` swapped, the draws taken in the order they began. -/
def swapSpans (cs : Seq) (spans : List Span) : List Seq :=
  match spans with
  | [] => []
  | first :: rest =>
    (siblings first.depth rest).map (fun second =>
      cs.take first.start ++ slice cs second ++
        (cs.drop (first.start + first.width)).take (second.start - (first.start + first.width)) ++
        slice cs first ++ cs.drop (second.start + second.width)) ++
      swapSpans cs rest

/-- Value moved from each choice to the one 8, 4, 3, 2 or 1 places after it, the earlier lowered to each of its
`probes` and the later raised by as much, then by 1 less where more than 1 moved, each where that stays within
`largest`. -/
def moveValues (cs : Seq) : List Seq :=
  widths.flatMap fun apart => (pairsFrom cs.length apart).flatMap fun i =>
    let j := i + apart
    let source := choiceAt cs i
    let target := choiceAt cs j
    (probes source).flatMap fun lowered =>
      let moved := source - lowered
      ((moved :: if moved > 1 then [moved - 1] else []).filter (· ≤ largest - target)).map fun raised =>
        (cs.set i lowered).set j (target + raised)

/-- The candidates `p` proposes from `cs`, whose run made `spans`, in order. -/
def Pass.candidates (p : Pass) (cs : Seq) (spans : List Span) : List Seq :=
  match p with
  | .deleteSpan => deleteSpans cs
  | .liftSpan => liftSpans cs spans
  | .zeroSpan => zeroSpans cs
  | .lowerChoice => lowerChoices cs
  | .lowerTogether => lowerTogethers cs
  | .reorder => reorders cs
  | .swapSpan => swapSpans cs spans
  | .moveValue => moveValues cs

end Grit
