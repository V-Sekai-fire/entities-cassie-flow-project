A headless Godot project that drives the cassie pen/mesh/curvenet operators and checks each stage against a recorded golden.

The engine is `4-entities/godot-cassie` (`V-Sekai-fire/entities-godot` at
`feat/module-cassie`), which adds `modules/cassie/` — the CASSIE Beautify /
arrangement / patch pipeline (RFD 2254) exposed to GDScript through the
`Cassie*` classes documented under `modules/cassie/doc_classes/`. The module
already carries C++ unit tests under `modules/cassie/tests/`; this project
is the black-box counterpart: it stands the classes up from a real Godot
project, runs the pipeline end-to-end on fixture strokes, and checks
determinism, invariants, and the doc-example scripts.

## Run and check

```sh
<godot> --headless --path . --script res://checks/run_all.gd
checks/run.sh <godot>                       # the check matrix and its controls
```

`checks/run_all.gd` exercises each operator against a fixture:

- beautify determinism: same input stroke → identical `CassieFinalStroke`
  hash across two runs;
- curvenet extraction: a planted 3-cycle sketch → three
  `CassieCurvenetKnot`s, and a scrambled input variant that must NOT match;
- patch pipeline: fixture curvenet → the same face count and vertex hash
  as the golden;
- constraint solver: over- and under-constrained fixtures return the
  documented error codes.

Every check ships with a negative control that asserts the broken input
fails (working agreement rule 2). A silent skip is a FAIL (rule 3).

## Layout

- `checks/` — GDScript checks and their fixtures
- `scenes/` — visual smoke scenes (not part of the headless gate)
- `.github/workflows/checks.yml` — runs `checks/run.sh` against a cassie
  Godot binary built from `4-entities/godot-cassie`

This project is not a deliverable. It is a gate on the cassie module's
public GDScript surface.

## Pen demo (interactive, driven by a computer-use agent)

`scenes/pen_demo.tscn` maps a mouse drag on the z=0 plane to one
`CassieSketcher` stroke through the workspace's 3D↔2D helper
(`addons/screen_projection/`, lifted from `udon2godot`'s `u.gd`). Each
committed stroke draws as a line and a bone chain on the `Rig` skeleton;
each closed cycle draws as an alpha-0.35 patch so the strokes behind it stay
readable. Counts land in `user://pen_demo_result.json` after every commit.

Measured 2026-09-17 on the `metal=no` editor build with
`--rendering-driver opengl3` (the Vulkan/MoltenVK path segfaults at window
creation on that build; three drags of 300 px at 60 steps each):

| run                              | nodes | edges | patches | triangles | bones |
| -------------------------------- | ----- | ----- | ------- | --------- | ----- |
| endpoints 14 px apart            | 6     | 3     | 0       | 0         | 27    |
| strokes overshoot and cross      | 6     | 3     | 0       | 0         | 27    |
| endpoints shared to the pixel    | 3     | 3     | 1       | 4612      | 27    |
| overshoot and cross, after split | 10    | 11    | 1       | 2366      | 27    |

The live commit path merges endpoints within `merge_epsilon` (0.02 units,
about 5 px at this camera). Before `add_stroke_intersecting` it did not
split strokes where they cross, and the second row is that defect; the
fourth row is the same three drags against `a9b477edaf`, where each stroke
is cut at its crossings and the inner triangle surfaces with the stubs left
outside it. Screenshots for all three are under `scenes/evidence/`.

The fourth row has one node and two edges more than the nine-and-nine the
doctest predicts for three straight strokes. The beautifier fits a curve to
each drag, so a stroke can cross a neighbour's stub as well as its middle;
the count is reported as measured, not reconciled.

## Hat fixture against the Unity capture

`modules/cassie/tests/test_cassie_pipeline_bench.h` replays the tracked
138-stroke hat fixture prefix by prefix and compares the union of every
cycle's stroke set against the 199 unique border sets in Unity CASSIE's
`allCreatedPatches` (`hat.json`, written by `lake exe hat_dump`). Set
semantics, because Unity lists a stroke once per segment it contributes.

Measured 2026-09-17 on `a45f5b143b`, `--no-skip --test-case="*Border-set
diff*"`:

| proximity | cycles detected | matched | false positive | false negative |
| --------- | --------------- | ------- | -------------- | -------------- |
| 0.0017    | 189             | 47      | 142            | 152            |
| 0.02      | 271             | 24      | 247            | 175            |

The floor was 26 matched before the walk was ported. The arrangement at
0.0017 matches the Lean model exactly (227 nodes, 399 edges); the walk
closes 88 cycles against Lean's 65 on the full fixture, and the C++ pins
that number as a witness.

Three departures from the Lean model are deliberate, and a unit fixture
the model gets wrong pins each one:

- the normal is carried across a node from the direction of travel;
  Unity passes `-prevSegment.GetTangentAt(node)` and the Lean port drops
  the negation, so a straight-through node becomes a half-turn about an
  arbitrary axis (Lean finds 0 of a cube's 6 faces);
- `reversed` is decided at each node from the transported normal rather
  than toggled after it, which lags one node (Lean finds 1 of a planar
  2x2 grid's 4 cells);
- the plane fit is converged rather than eight Y-up power iterations,
  which on a z=0 sketch never leaves the seed's invariant subspace.

Of the 152 borders Unity has that the walk does not, 49 are strict
subsets of a cycle it did find and 24 differ by one stroke. The largest
remaining cause is bundles of near-parallel strokes between the same two
nodes (the mirror pairs 4–9 at the hat apex), where the plane fit and the
CCW ring are degenerate: the walk pairs (4,6) and (5,7) where Unity paired
(6,7). Not fixed; recorded so the next number has a floor.
