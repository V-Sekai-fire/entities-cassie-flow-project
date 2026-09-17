#!/usr/bin/env bash
# Drives the cassie GDScript surface against a Godot binary built from
# 4-entities/godot-cassie and reports per-check pass/fail with a control row.
#   checks/run.sh <godot binary>
set -u
G="${1:?path to a godot binary with modules/cassie compiled in}"
cd "$(dirname "$0")/.."
fails=0
runs=0
printf '%-40s %-6s  %s\n' "check" "exit" "verdict"
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
  printf '%-40s %-6d  %s\n' "$name" "$code" "${verdict:-none}"
  runs=$((runs + 1))
  [ "$code" -eq 0 ] || fails=$((fails + 1))
done
echo "$fails of $runs checks failed"
exit $fails
