#!/usr/bin/env bash
# Drives the cassie GDScript surface against a Godot binary built from
# 4-entities/godot-cassie/modules/cassie. Each check runs its own negative
# control inline and prints a summary. An unresolvable binary is a FAIL
# (rule 3: silent skips read like passes).
#   GODOT_BIN=/path/to/godot checks/run.sh
set -u
cd "$(dirname "$0")/.."
G="${GODOT_BIN:-../../4-entities/godot-cassie/bin/godot.macos.editor.arm64}"
if [ ! -x "$G" ]; then
  echo "FAIL cannot locate a Godot binary at $G (set GODOT_BIN)"
  exit 1
fi

fails=0
runs=0
printf '%-30s %-6s  %s\n' "check" "exit" "verdict / control"
for script in checks/beautify_determinism.gd \
              checks/curvenet_extract.gd \
              checks/patch_pipeline.gd \
              checks/constraint_solver.gd; do
  name=$(basename "$script" .gd)
  out="checks/out/$name"
  mkdir -p "$out"
  timeout 120 "$G" --headless --path . --script "res://$script" -- "--out=$PWD/$out" > "$out/log.txt" 2>&1
  code=$?
  verdict=$(grep -h "^DONE\|^FAIL\|control caught" "$out/log.txt" | tail -1)
  printf '%-30s %-6d  %s\n' "$name" "$code" "${verdict:-none}"
  runs=$((runs + 1))
  [ "$code" -eq 0 ] || fails=$((fails + 1))
done
echo "$fails of $runs checks failed"
exit "$fails"
