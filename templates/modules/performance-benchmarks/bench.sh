#!/usr/bin/env bash
# bench.sh — run stack benchmarks and compare against harness/baselines.json.
#
# Run by the reviewer at audit_level: strict. The installer never runs this
# script. Without a baseline the script records values and warns (never blocks).
#
# Usage: bash harness/tools/bench.sh
# Exit codes: 0 = ok or record-only, 1 = regression beyond critical threshold, 2 = usage error

set -uo pipefail

BASELINES="harness/baselines.json"
MEASURED=0
REJECT=0
OUT="$(mktemp)"
trap 'rm -f "$OUT" harness/.bench-last.json' EXIT

STACK=""
if [ -f "tsconfig.json" ]; then STACK="typescript"
elif [ -f "package.json" ]; then STACK="node"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then STACK="python"
elif [ -f "Cargo.toml" ]; then STACK="rust"
else STACK="generic"
fi

echo "# Benchmark Report (stack: $STACK)"
echo ""

case "$STACK" in
  python)
    if python3 -c "import pytest_benchmark" >/dev/null 2>&1; then
      echo "## Runner: pytest-benchmark"
      if python3 -m pytest -q tests --benchmark-only --benchmark-json=harness/.bench-last.json > "$OUT" 2>&1; then
        tail -n 15 "$OUT"
        MEASURED=1
      else
        echo "pytest --benchmark-only failed (no benchmark-marked tests?)"
        cat "$OUT"
      fi
    else
      echo "## Runner: pytest-benchmark — SKIPPED (not installed; pip install pytest-benchmark)"
      echo "Record-only: no measurements taken."
    fi
    ;;
  typescript|node)
    if [ -d "node_modules/vitest" ] && npx vitest bench --run > "$OUT" 2>&1; then
      echo "## Runner: vitest bench"
      tail -n 15 "$OUT"
      MEASURED=1
    else
      echo "## Runner: vitest bench — SKIPPED (not configured). Record-only."
    fi
    ;;
  rust)
    if { [ -d "benches" ] || grep -q "\[\[bench\]\]" Cargo.toml 2>/dev/null; } && cargo bench > "$OUT" 2>&1; then
      echo "## Runner: cargo bench"
      tail -n 15 "$OUT"
      MEASURED=1
    else
      echo "## Runner: cargo bench — SKIPPED (no benches configured). Record-only."
    fi
    ;;
  *)
    echo "## Checklist-only (no automated benchmarks for stack: $STACK)"
    ;;
esac

# Compare against baselines when we have measurements, a non-empty baseline
# file, and python3 available (only the python runner produces parseable JSON).
if [ "$MEASURED" -eq 1 ] && [ "$STACK" = "python" ] \
   && [ -s "$BASELINES" ] \
   && [ "$(cat "$BASELINES")" != "{}" ] \
   && command -v python3 >/dev/null 2>&1 \
   && [ -f "harness/.bench-last.json" ]; then
  echo ""
  echo "## Baseline comparison"
  if ! python3 - "$BASELINES" "harness/.bench-last.json" <<'PYEOF'; then
import json, sys
base = json.load(open(sys.argv[1]))
data = json.load(open(sys.argv[2]))
last = {b["name"]: b["stats"]["mean"] * 1000.0 for b in data["benchmarks"]}
reject = False
for name, entry in base.items():
    if name not in last:
        print(f"- {name}: no measurement found (baseline stale?)")
        continue
    mean_ms = last[name]
    ref = entry.get("mean_ms")
    th = entry.get("thresholds", {}).get("mean_ms", {})
    warn_m = th.get("warning", 1.5)
    crit_m = th.get("critical", 2.0)
    if ref is None:
        print(f"- {name}: measured {mean_ms:.1f} ms (no reference mean_ms yet; record it)")
        continue
    ratio = mean_ms / ref
    if ratio > crit_m:
        print(f"- {name}: REGRESSION {ratio:.2f}x vs baseline {ref:.1f} ms (critical {crit_m}x)")
        reject = True
    elif ratio > warn_m:
        print(f"- {name}: WARNING {ratio:.2f}x vs baseline {ref:.1f} ms")
    else:
        print(f"- {name}: ok {mean_ms:.1f} ms ({ratio:.2f}x baseline)")
sys.exit(1 if reject else 0)
PYEOF
    REJECT=1
  fi
elif [ "$MEASURED" -eq 1 ]; then
  echo ""
  echo "No usable baseline in $BASELINES — values recorded only (add entries after review)."
fi

echo ""
if [ "$REJECT" -eq 1 ]; then
  echo "VERDICT: benchmark regression beyond critical threshold — approval rejected (strict)."
  exit 1
fi
echo "VERDICT: no benchmark regression."
exit 0
