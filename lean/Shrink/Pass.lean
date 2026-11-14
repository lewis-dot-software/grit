import Shrink.Sequence

/-!
The passes: each a function from the current sequence, and the spans its run made, to its candidates, in a fixed
order, and the order a round takes them in.
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
  | deleteAndLower
  | lowerAndCopy
  | deleteAndRaise
  deriving DecidableEq, Repr

/-- The passes after `p`, in the order a round takes them. -/
def Pass.later (p : Pass) : List Pass :=
  match p with
  | .deleteSpan =>
    [.liftSpan, .zeroSpan, .lowerChoice, .lowerTogether, .reorder, .swapSpan, .moveValue, .deleteAndLower,
      .lowerAndCopy, .deleteAndRaise]
  | .liftSpan =>
    [.zeroSpan, .lowerChoice, .lowerTogether, .reorder, .swapSpan, .moveValue, .deleteAndLower, .lowerAndCopy,
      .deleteAndRaise]
  | .zeroSpan =>
    [.lowerChoice, .lowerTogether, .reorder, .swapSpan, .moveValue, .deleteAndLower, .lowerAndCopy, .deleteAndRaise]
  | .lowerChoice => [.lowerTogether, .reorder, .swapSpan, .moveValue, .deleteAndLower, .lowerAndCopy, .deleteAndRaise]
  | .lowerTogether => [.reorder, .swapSpan, .moveValue, .deleteAndLower, .lowerAndCopy, .deleteAndRaise]
  | .reorder => [.swapSpan, .moveValue, .deleteAndLower, .lowerAndCopy, .deleteAndRaise]
  | .swapSpan => [.moveValue, .deleteAndLower, .lowerAndCopy, .deleteAndRaise]
  | .moveValue => [.deleteAndLower, .lowerAndCopy, .deleteAndRaise]
  | .deleteAndLower => [.lowerAndCopy, .deleteAndRaise]
  | .lowerAndCopy => [.deleteAndRaise]
  | .deleteAndRaise => []

/-- Whether a round takes `p` only where it has accepted nothing yet. -/
def Pass.costly (p : Pass) : Bool :=
  match p with
  | .deleteSpan => false
  | .liftSpan => false
  | .zeroSpan => false
  | .lowerChoice => false
  | .lowerTogether => false
  | .reorder => false
  | .swapSpan => false
  | .moveValue => false
  | .deleteAndLower => true
  | .lowerAndCopy => true
  | .deleteAndRaise => true

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

/-- Each pair of choices within `length`, as how far apart they are and the place of the first, the farthest apart
first and each from the first on. -/
def pairs (length : Nat) : List (Nat × Nat) :=
  widths.flatMap fun apart => (pairsFrom length apart).map fun i => (apart, i)

/-- Whether `pair` comes before `other` among `pairs`. -/
def precedes (pair other : Nat × Nat) : Bool :=
  pair.1 > other.1 || (pair.1 == other.1 && pair.2 < other.2)

/-- Value moved from the first of `pair`'s choices of `cs` to the second, the first lowered to each of its `probes` and
the second raised by as much, then by 1 less where more than 1 moved, each where that stays within `largest`. -/
def moveValue (cs : Seq) (pair : Nat × Nat) : List Seq :=
  let i := pair.2
  let j := pair.2 + pair.1
  let source := choiceAt cs i
  let target := choiceAt cs j
  (probes source).flatMap fun lowered =>
    let moved := source - lowered
    ((moved :: if moved > 1 then [moved - 1] else []).filter (· ≤ largest - target)).map fun raised =>
      (cs.set i lowered).set j (target + raised)

/-- Value moved between each of `pairs`, in order. -/
def moveValues (cs : Seq) : List Seq := (pairs cs.length).flatMap (moveValue cs)

/-- Each two choices 8, 4, 3, 2 or 1 apart, the farthest apart first and each from the first on, both lowered by 1,
where both are above 0, each with each span of 8, 4, 3, 2 or 1 choices just before the first of them deleted, the
widest first. -/
def deleteAndLowers (cs : Seq) : List Seq :=
  widths.flatMap fun apart => (pairsFrom cs.length apart).flatMap fun i =>
    let j := i + apart
    if choiceAt cs i > 0 ∧ choiceAt cs j > 0 then
      (widths.filter (· ≤ i)).map fun width =>
        cs.take (i - width) ++ [choiceAt cs i - 1] ++ (cs.drop (i + 1)).take (j - (i + 1)) ++
          [choiceAt cs j - 1] ++ cs.drop (j + 1)
    else []

/-- Each choice, from the first, lowered to each of its `probes`, each with each 0 among the 8 choices after it set to
the choice that follows the 0, where that is above 0. -/
def lowerAndCopies (cs : Seq) : List Seq :=
  (List.range cs.length).flatMap fun i => (probes (choiceAt cs i)).flatMap fun lowered =>
    ((List.range 8).map (i + 1 + ·)).filterMap fun j =>
      if j + 1 < cs.length ∧ choiceAt cs j = 0 ∧ choiceAt cs (j + 1) > 0 then
        some ((cs.set i lowered).set j (choiceAt cs (j + 1)))
      else none

/-- Each span of 8, 4, 3, 2 or 1 choices deleted, the spans in the order `deleteSpans` takes them, with the choice after
the span raised by the span's sum, where that sum is above 0 and the raise stays within `largest`. -/
def deleteAndRaises (cs : Seq) : List Seq :=
  widths.flatMap fun width => (startsBack (cs.length - 1) width).filterMap fun start =>
    let after := start + width
    let sum := ((cs.drop start).take width).sum
    if sum > 0 ∧ choiceAt cs after + sum ≤ largest then
      some (cs.take start ++ [choiceAt cs after + sum] ++ cs.drop (after + 1))
    else none

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
  | .deleteAndLower => deleteAndLowers cs
  | .lowerAndCopy => lowerAndCopies cs
  | .deleteAndRaise => deleteAndRaises cs

/-- The pair of `ps` whose candidates of `moveValue` from `cs` hold the one at `position` among them all, or none where
none does. -/
def toldPair (cs : Seq) : List (Nat × Nat) → Nat → Option (Nat × Nat)
  | [], _ => none
  | pair :: rest, position =>
    if position < (moveValue cs pair).length then some pair
    else toldPair cs rest (position - (moveValue cs pair).length)

/-- How many candidates `moveValues` proposes from `cs` before the first of `told`'s pair or of the pairs after it, or how
many it proposes in all where `told` is none. -/
def movesBefore (cs : Seq) (told : Option (Nat × Nat)) : Nat :=
  (((pairs cs.length).takeWhile fun pair =>
    match told with
    | some t => precedes pair t
    | none => true).map fun pair => (moveValue cs pair).length).sum

/-- The place among the candidates `p` proposes from `next` to go on from, where its candidate at `position` among those
it proposes from `cs` was told as failing and `next` is the record that candidate's run read: for `moveValue`, the first
candidate of the told candidate's pair among `next`'s, or of the pairs after it where `next` is too short to hold it, and
for every other pass, `position`. -/
def Pass.resumeAt (p : Pass) (cs : Seq) (position : Nat) (next : Seq) : Nat :=
  match p with
  | .deleteSpan => position
  | .liftSpan => position
  | .zeroSpan => position
  | .lowerChoice => position
  | .lowerTogether => position
  | .reorder => position
  | .swapSpan => position
  | .moveValue => movesBefore next (toldPair cs (pairs cs.length) position)
  | .deleteAndLower => position
  | .lowerAndCopy => position
  | .deleteAndRaise => position

end Grit
