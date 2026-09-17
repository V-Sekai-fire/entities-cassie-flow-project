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

The live commit path merges endpoints within `merge_epsilon` (0.02 units,
about 5 px at this camera) and does not split strokes where they cross, so
the second row is the defect the crossing case exposes and the third row is
the pipeline working. Screenshots for both are under `scenes/evidence/`.
