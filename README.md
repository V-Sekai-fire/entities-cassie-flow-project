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
