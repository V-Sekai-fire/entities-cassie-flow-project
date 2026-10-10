# entities-cassie-flow-project

An engine project that drives the cassie pen, mesh and curvenet operators and checks each stage against a recorded golden.

## What it is for

The operators come from the cassie module in `V-Sekai-fire/entities-godot`, named after the CASSIE curve-and-surface sketching paper that CITATION.cff cites. Every check carries a planted negative control. RFD 2269 in [manuals-weftspun](https://github.com/V-Sekai-fire/manuals-weftspun) owns the curvenet parity gate these checks feed.

## Build and run

Build an engine binary with the cassie module, then run the checks against it:

```sh
GODOT_BIN=<engine binary> checks/run.sh
```

## Licence

MIT. See [LICENSE](LICENSE).
