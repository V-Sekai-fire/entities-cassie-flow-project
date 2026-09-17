A headless Godot project that drives the cassie pen/mesh/curvenet operators and checks each stage against a recorded golden.

```sh
<godot> --headless --path . --script res://checks/run_all.gd
checks/run.sh <godot>                       # the check matrix and its controls
Checks/run_all.gd # exercises each operator against a fixture:
```
