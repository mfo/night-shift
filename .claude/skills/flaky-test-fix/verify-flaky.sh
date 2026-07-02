#!/bin/bash
set -euo pipefail

# Usage: bash verify-flaky.sh <spec_file_or_spec:line> [runs]
# Accepts spec file with optional line: spec/system/foo_spec.rb:42
# System specs (spec/system/): default 20 runs
# Other specs: default 50 runs

spec="${1:?Usage: verify-flaky.sh <spec_file[:line]> [runs]}"
spec_file="${spec%%:*}"

if [[ "$spec_file" == spec/system/* ]]; then
  default_runs=20
else
  default_runs=50
fi
runs="${2:-$default_runs}"

passed=0
failed=0

echo "=== Stress test: $spec ($runs runs) ==="
echo ""

for i in $(seq 1 "$runs"); do
  output=$(bundle exec rspec "$spec" --order random --format progress 2>&1) || true
  seed=$(echo "$output" | grep -o 'Randomized with seed [0-9]*' | grep -o '[0-9]*' || echo "?")
  summary=$(echo "$output" | tail -1)

  if echo "$summary" | grep -q '0 failures'; then
    passed=$((passed + 1))
    echo "Run $i/$runs PASS (seed $seed) — $passed passed, $failed failed"
  else
    failed=$((failed + 1))
    echo "Run $i/$runs FAIL (seed $seed) — $passed passed, $failed failed"
    echo "  Replay: bundle exec rspec $spec --seed $seed"
  fi
done

echo ""
echo "=== Result: $passed/$runs passed, $failed failed ==="
if [ "$failed" -gt 0 ]; then
  echo "FLAKY — fix incomplete"
  exit 1
else
  echo "STABLE"
  exit 0
fi
