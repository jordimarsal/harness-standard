#!/usr/bin/env bash
# tests/test-install.sh — End-to-end tests for init.sh installer
#
# Usage: ./tests/test-install.sh
# Verifies both installation modes (claude / opencode), the harness/ layout,
# the interactive prompt, reinstall refusal, and the copied verify script.

set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$REPO_DIR/init.sh"

PASS=0
FAIL=0
TMP_ROOT=""
FAILED_NAMES=()

# ── Assertion helpers ──────────────────────────────────
assert_file() {  # assert_file <name> <path>
  if [ -f "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: missing file $2")
    echo "    FAIL: expected file $2"
  fi
}

assert_no_file() {  # assert_no_file <name> <path>
  if [ ! -e "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: file $2 should not exist")
    echo "    FAIL: file $2 should not exist"
  fi
}

assert_dir() {  # assert_dir <name> <path>
  if [ -d "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: missing dir $2")
    echo "    FAIL: expected dir $2"
  fi
}

assert_grep() {  # assert_grep <name> <pattern> <file>
  if grep -q "$2" "$3" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: pattern '$2' not in $3")
    echo "    FAIL: pattern '$2' not found in $3"
  fi
}

assert_executable() {  # assert_executable <name> <path>
  if [ -x "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: $2 not executable")
    echo "    FAIL: $2 is not executable"
  fi
}

assert_count() {  # assert_count <name> <pattern> <file> <expected-count>
  local got
  got=$(grep -c "$2" "$3" 2>/dev/null || true)
  if [ "$got" -eq "$4" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: expected $4 of '$2' in $3, got $got")
    echo "    FAIL: '$2' appears $got times in $3 (expected $4)"
  fi
}

assert_no_dir() {  # assert_no_dir <name> <path>
  if [ ! -d "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: dir $2 should not exist")
    echo "    FAIL: dir $2 should not exist"
  fi
}

# ── Shared layout assertions (everything except docs/ under harness/) ──
assert_harness_layout() {  # assert_harness_layout <test-name> <project-dir>
  local t="$1" d="$2"
  assert_dir "$t" "$d/harness"
  assert_file "$t" "$d/harness/CHECKPOINTS.md"
  assert_file "$t" "$d/harness/feature_list.json"
  assert_executable "$t" "$d/harness/init.sh"
  assert_file "$t" "$d/harness/progress/current.md"
  assert_file "$t" "$d/harness/progress/history.md"
  assert_dir "$t" "$d/harness/specs"
  # docs/ stays at project root
  assert_file "$t" "$d/docs/architecture.md"
  assert_file "$t" "$d/docs/conventions.md"
  assert_file "$t" "$d/docs/specs.md"
  assert_file "$t" "$d/docs/verification.md"
  # nothing leaked to root
  assert_no_file "$t" "$d/CHECKPOINTS.md"
  assert_no_file "$t" "$d/feature_list.json"
  assert_no_file "$t" "$d/init.sh"
  assert_no_file "$t" "$d/progress"
  assert_no_file "$t" "$d/specs"
}

new_project() {  # new_project <name> — echoes the created dir
  local d="$TMP_ROOT/$1"
  mkdir -p "$d"
  echo "$d"
}

run_test() {  # run_test <name> — echoes header
  echo ""
  echo "=== $1 ==="
}

# ── Tests ──────────────────────────────────────────────

test_claude_mode_typescript() {
  local t="claude mode installs CLAUDE.md + .claude at root, rest in harness/"
  run_test "$t"
  local d; d=$(new_project "claude-ts")
  touch "$d/tsconfig.json"
  (cd "$d" && "$INIT" --tool=claude >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/CLAUDE.md"
  assert_grep "$t" "Stack: TypeScript" "$d/CLAUDE.md"
  assert_grep "$t" "harness/feature_list.json" "$d/CLAUDE.md"
  for a in leader spec-author implementer reviewer; do
    assert_file "$t" "$d/.claude/agents/$a.md"
  done
  assert_file "$t" "$d/.claude/settings.json"
  assert_grep "$t" "npx vitest run" "$d/.claude/settings.json"
  assert_harness_layout "$t" "$d"
  assert_no_file "$t" "$d/AGENTS.md"
  assert_no_file "$t" "$d/.opencode"
  assert_no_file "$t" "$d/opencode.json"
}

test_opencode_mode_generic() {
  local t="opencode mode installs AGENTS.md + .opencode at root, rest in harness/"
  run_test "$t"
  local d; d=$(new_project "opencode-generic")
  (cd "$d" && "$INIT" --tool=opencode >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/AGENTS.md"
  assert_grep "$t" "harness/feature_list.json" "$d/AGENTS.md"
  assert_grep "$t" "harness/init.sh" "$d/AGENTS.md"
  for a in leader spec-author implementer reviewer; do
    assert_file "$t" "$d/.opencode/agent/$a.md"
  done
  assert_file "$t" "$d/opencode.json"
  assert_harness_layout "$t" "$d"
  assert_no_file "$t" "$d/CLAUDE.md"
  assert_no_file "$t" "$d/.claude"
}

test_interactive_prompt() {
  local t="interactive prompt accepts 'o' for opencode"
  run_test "$t"
  local d; d=$(new_project "interactive-o")
  (cd "$d" && printf 'o\n' | "$INIT" >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/AGENTS.md"
  assert_file "$t" "$d/opencode.json"

  local t2="interactive prompt accepts 'c' for claude"
  run_test "$t2"
  d=$(new_project "interactive-c")
  (cd "$d" && printf 'c\n' | "$INIT" >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t2: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t2" "$d/CLAUDE.md"
  assert_file "$t2" "$d/.claude/settings.json"
}

test_invalid_tool_rejected() {
  local t="invalid --tool value is rejected"
  run_test "$t"
  local d; d=$(new_project "invalid-tool")
  if (cd "$d" && "$INIT" --tool=vim >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: should exit non-zero")
    echo "    FAIL: init.sh accepted --tool=vim"
  else
    PASS=$((PASS + 1))
  fi
}

test_interactive_module_menu() {
  local t="interactive menu lists every module; empty answers install none"
  run_test "$t"
  local d; d=$(new_project "interactive-menu")
  local out
  out="$(cd "$d" && printf 'o\n\n\n' | "$INIT" 2>&1)" || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  printf '%s\n' "$out" > "$d/init-output.txt"
  for m in architecture-catalog iterative-refinement decision-memory project-scanner security-audit performance-benchmarks wekan-tickets; do
    assert_grep "$t" "$m" "$d/init-output.txt"
  done
  assert_grep "$t" "Audit level" "$d/init-output.txt"
  assert_grep "$t" '"modules": \[\]' "$d/harness/feature_list.json"
  assert_grep "$t" '"audit_level": "basic"' "$d/harness/feature_list.json"
  assert_file "$t" "$d/harness/tools/validate-feature-list.py"
  assert_no_file "$t" "$d/harness/tools/scan.py"

  local t2="interactive menu accepts module selection by number"
  run_test "$t2"
  d=$(new_project "interactive-select")
  # menu order is the alphabetical module dir order; 1 = architecture-catalog
  out="$(cd "$d" && printf 'o\n1,99\n\n' | "$INIT" 2>&1)" || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t2: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  printf '%s\n' "$out" > "$d/init-output.txt"
  assert_file "$t2" "$d/docs/architecture-options.md"
  assert_grep "$t2" '"architecture-catalog"' "$d/harness/feature_list.json"
  assert_grep "$t2" "Ignoring invalid module number" "$d/init-output.txt"

  local t3="interactive audit level prompt accepts standard"
  run_test "$t3"
  d=$(new_project "interactive-audit")
  (cd "$d" && printf 'o\n\n2\n' | "$INIT" >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t3: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_grep "$t3" '"audit_level": "standard"' "$d/harness/feature_list.json"
}

test_reinstall_refused() {
  local t="reinstall is refused when harness exists"
  run_test "$t"
  local d; d=$(new_project "reinstall")
  (cd "$d" && "$INIT" --tool=claude >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: first install failed"); return
  }
  if (cd "$d" && "$INIT" --tool=claude >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: second install should fail")
    echo "    FAIL: reinstall was allowed"
  else
    PASS=$((PASS + 1))
  fi
}

test_verify_script_runs() {
  local t="copied harness/init.sh verification passes in fresh project"
  run_test "$t"
  local d; d=$(new_project "verify")
  (cd "$d" && "$INIT" --tool=opencode >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: install failed"); return
  }
  if (cd "$d" && ./harness/init.sh >/dev/null 2>&1); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: harness/init.sh exited non-zero")
    echo "    FAIL: harness/init.sh failed (no test framework project)"
  fi
}

test_python_stack() {
  local t="python stack installs pytest commands and quality-gate criteria"
  run_test "$t"
  local d; d=$(new_project "python-stack")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=claude >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/CLAUDE.md"
  assert_grep "$t" "python3 -m pytest" "$d/.claude/settings.json"
  assert_grep "$t" "Stack: Python" "$d/CLAUDE.md"
  assert_grep "$t" "ruff" "$d/CLAUDE.md"
  assert_grep "$t" "black" "$d/CLAUDE.md"
  assert_grep "$t" "mypy" "$d/CLAUDE.md"
  assert_grep "$t" "pytest" "$d/CLAUDE.md"
  assert_grep "$t" "region " "$d/CLAUDE.md"
  if grep -q "unittest" "$d/.claude/settings.json"; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: settings.json still references unittest")
    echo "    FAIL: settings.json still references unittest"
  else
    PASS=$((PASS + 1))
  fi
}

test_force_reinstall_preserves_state() {
  local t="--force reinstalls templates and preserves user state"
  run_test "$t"
  local d; d=$(new_project "force-same")
  (cd "$d" && "$INIT" --tool=claude >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: first install failed"); return
  }
  PASS=$((PASS + 1))
  # simulate user state
  echo '{"custom": true}' > "$d/harness/feature_list.json"
  echo "session in progress" > "$d/harness/progress/current.md"
  echo "my architecture" > "$d/docs/architecture.md"
  echo "my conventions" > "$d/docs/conventions.md"
  mkdir -p "$d/harness/specs/myfeature"
  echo "req" > "$d/harness/specs/myfeature/requirements.md"
  (cd "$d" && "$INIT" --force --tool=claude >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: force install failed"); return
  }
  PASS=$((PASS + 1))
  # user state preserved
  assert_grep "$t" '"custom": true' "$d/harness/feature_list.json"
  assert_grep "$t" "session in progress" "$d/harness/progress/current.md"
  assert_grep "$t" "my architecture" "$d/docs/architecture.md"
  assert_grep "$t" "my conventions" "$d/docs/conventions.md"
  assert_file "$t" "$d/harness/specs/myfeature/requirements.md"
  # templates refreshed
  assert_file "$t" "$d/CLAUDE.md"
  assert_file "$t" "$d/.claude/settings.json"
  assert_executable "$t" "$d/harness/init.sh"
  assert_file "$t" "$d/harness/CHECKPOINTS.md"
  assert_file "$t" "$d/docs/specs.md"
}

test_force_switch_tool() {
  local t="--force with different tool removes old entry point and tool dir"
  run_test "$t"
  local d; d=$(new_project "force-switch")
  (cd "$d" && "$INIT" --tool=claude >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: first install failed"); return
  }
  PASS=$((PASS + 1))
  (cd "$d" && "$INIT" --force --tool=opencode >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: force switch failed"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/AGENTS.md"
  assert_file "$t" "$d/opencode.json"
  assert_file "$t" "$d/.opencode/agent/leader.md"
  assert_no_file "$t" "$d/CLAUDE.md"
  assert_no_file "$t" "$d/.claude"
  assert_harness_layout "$t" "$d"
}

test_module_manifests_valid() {
  local t="every module manifest parses and its referenced files exist"
  run_test "$t"
  if [ ! -d "$REPO_DIR/templates/modules" ]; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: templates/modules missing")
    echo "    FAIL: templates/modules does not exist"
    return
  fi
  local n=0
  for mf in "$REPO_DIR"/templates/modules/*/manifest.json; do
    [ -e "$mf" ] || continue
    n=$((n + 1))
    if python3 - "$mf" "$(dirname "$mf")" <<'PYEOF' >/dev/null 2>&1; then
import json, os, sys
mf, mdir = sys.argv[1], sys.argv[2]
data = json.load(open(mf))
required = {"name", "description", "stacks", "injects", "verify"}
missing = required - set(data)
assert not missing, f"missing keys: {missing}"
assert isinstance(data["stacks"], list) and data["stacks"], "stacks must be a non-empty list"
for inj in data["injects"]:
    assert {"src", "dst", "mode"} <= set(inj), f"bad inject: {inj}"
    assert os.path.isfile(os.path.join(mdir, inj["src"])), f"missing src file: {inj['src']}"
for v in data["verify"]:
    assert isinstance(v, str)
    assert not v.startswith("/"), f"verify path must be project-relative: {v}"
sys.exit(0)
PYEOF
      PASS=$((PASS + 1))
    else
      FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: invalid manifest $mf")
      echo "    FAIL: invalid manifest: $mf"
    fi
  done
  if [ "$n" -eq 0 ]; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: no module manifests found")
    echo "    FAIL: no module manifests found"
  fi
}

test_modules_install() {
  local t="--modules installs module files and records them in feature_list.json"
  run_test "$t"
  local d; d=$(new_project "modules-basic")
  (cd "$d" && "$INIT" --tool=opencode --modules=architecture-catalog,decision-memory --audit-level=standard >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/docs/architecture-options.md"
  assert_file "$t" "$d/harness/decisions/_template.md"
  assert_grep "$t" '"architecture-catalog"' "$d/harness/feature_list.json"
  assert_grep "$t" '"decision-memory"' "$d/harness/feature_list.json"
  assert_grep "$t" '"audit_level": "standard"' "$d/harness/feature_list.json"
}

test_default_install_no_modules() {
  local t="default install records empty modules and basic audit level"
  run_test "$t"
  local d; d=$(new_project "default-nomod")
  (cd "$d" && "$INIT" --tool=opencode >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_grep "$t" '"modules": \[\]' "$d/harness/feature_list.json"
  assert_grep "$t" '"audit_level": "basic"' "$d/harness/feature_list.json"
  assert_file "$t" "$d/harness/tools/validate-feature-list.py"
  assert_no_file "$t" "$d/harness/tools/scan.py"
  assert_no_file "$t" "$d/harness/tools/audit-security.sh"
  assert_no_file "$t" "$d/harness/baselines.json"
  assert_no_file "$t" "$d/harness/wekan.json"
  assert_no_dir "$t" "$d/harness/decisions"
  assert_no_file "$t" "$d/docs/architecture-options.md"
  assert_no_file "$t" "$d/docs/iteration-protocol.md"
}

test_invalid_module_rejected() {
  local t="--modules with an unknown name is rejected"
  run_test "$t"
  local d; d=$(new_project "invalid-module")
  if (cd "$d" && "$INIT" --tool=claude --modules=nope >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: should exit non-zero")
    echo "    FAIL: init.sh accepted --modules=nope"
  else
    PASS=$((PASS + 1))
  fi
}

test_invalid_audit_level_rejected() {
  local t="invalid --audit-level value is rejected"
  run_test "$t"
  local d; d=$(new_project "invalid-audit")
  if (cd "$d" && "$INIT" --tool=claude --audit-level=paranoid >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: should exit non-zero")
    echo "    FAIL: init.sh accepted --audit-level=paranoid"
  else
    PASS=$((PASS + 1))
  fi
}

test_module_filtered_by_stack() {
  local t="stack-incompatible module is skipped with a warning"
  run_test "$t"
  local d; d=$(new_project "stack-filter")
  local out
  out="$(cd "$d" && "$INIT" --tool=claude --modules=project-scanner 2>&1)" || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  printf '%s\n' "$out" > "$d/init-output.txt"
  assert_grep "$t" "does not support stack" "$d/init-output.txt"
  assert_no_file "$t" "$d/harness/tools/scan.py"
  if grep -q '"project-scanner"' "$d/harness/feature_list.json"; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: skipped module recorded in feature_list.json")
    echo "    FAIL: skipped module recorded in feature_list.json"
  else
    PASS=$((PASS + 1))
  fi
}

test_project_scanner_module() {
  local t="project-scanner installs on python stack and scan.py answers queries"
  run_test "$t"
  local d; d=$(new_project "scanner")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=opencode --modules=project-scanner >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/harness/tools/scan.py"
  # Fixture project code
  mkdir -p "$d/core"
  cat > "$d/core/models.py" <<'EOF'
"""Domain models."""


class Order:
    """An order aggregate."""


def create_order():
    return Order()
EOF
  cat > "$d/core/service.py" <<'EOF'
"""Service layer."""
from core.models import Order


class OrderService:
    pass
EOF
  (cd "$d" && python3 harness/tools/scan.py --summary > summary.txt) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: scan.py --summary failed"); return
  }
  PASS=$((PASS + 1))
  assert_grep "$t" "core/models.py" "$d/summary.txt"
  assert_grep "$t" "core/service.py" "$d/summary.txt"
  (cd "$d" && python3 harness/tools/scan.py --impact core/service.py > impact.txt) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: scan.py --impact failed"); return
  }
  PASS=$((PASS + 1))
  # service.py depends on models.py — proves module-name resolution works
  assert_grep "$t" "core/models.py" "$d/impact.txt"
  if (cd "$d" && python3 harness/tools/scan.py --duplicates > dupes.txt); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: scan.py --duplicates failed")
    echo "    FAIL: scan.py --duplicates exited non-zero"
  fi
}

test_security_audit_module() {
  local t="security-audit installs checklist, tool, C7; script degrades without tools"
  run_test "$t"
  local d; d=$(new_project "sec-audit")
  (cd "$d" && "$INIT" --tool=claude --modules=security-audit --audit-level=standard >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_executable "$t" "$d/harness/tools/audit-security.sh"
  assert_count "$t" "harness:module:security-audit:start" "$d/docs/verification.md" 1
  assert_grep "$t" "Security Audit Checklist" "$d/docs/verification.md"
  assert_grep "$t" "C7 — Audit" "$d/harness/CHECKPOINTS.md"
  assert_count "$t" "harness:module:audit-checkpoint:start" "$d/harness/CHECKPOINTS.md" 1
  # Generic project without tools: the script degrades to checklist-only, exit 0
  if (cd "$d" && bash harness/tools/audit-security.sh > audit-report.txt 2>&1); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: audit-security.sh non-zero on tool-less project")
    echo "    FAIL: audit-security.sh should degrade to checklist-only with exit 0"
  fi
  assert_grep "$t" "Checklist" "$d/audit-report.txt"
}

test_modules_install_strict() {
  local t="strict install injects audit modules exactly once, C7, and feature_list entries"
  run_test "$t"
  local d; d=$(new_project "modules-strict")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=opencode --modules=security-audit,performance-benchmarks --audit-level=strict >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_executable "$t" "$d/harness/tools/audit-security.sh"
  assert_executable "$t" "$d/harness/tools/bench.sh"
  assert_file "$t" "$d/harness/baselines.json"
  assert_count "$t" "harness:module:security-audit:start" "$d/docs/verification.md" 1
  assert_count "$t" "harness:module:performance-benchmarks:start" "$d/docs/verification.md" 1
  assert_grep "$t" "C7 — Audit" "$d/harness/CHECKPOINTS.md"
  assert_grep "$t" '"security-audit"' "$d/harness/feature_list.json"
  assert_grep "$t" '"performance-benchmarks"' "$d/harness/feature_list.json"
  assert_grep "$t" '"audit_level": "strict"' "$d/harness/feature_list.json"
}

test_audit_json_output() {
  local t="audit-security.sh --json emits protocol v1 (generic checklist-only)"
  run_test "$t"
  local d; d=$(new_project "audit-json")
  (cd "$d" && "$INIT" --tool=opencode --modules=security-audit >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: install failed"); return
  }
  PASS=$((PASS + 1))
  if (cd "$d" && bash harness/tools/audit-security.sh --json > audit.json 2>/dev/null); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: --json exited non-zero"); return
  fi
  if python3 - "$d/audit.json" <<'PYEOF' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
assert d["tool"] == "audit-security" and d["protocol"] == 1
assert d["stack"] == "generic" and d["mode"] == "checklist-only"
assert d["verdict"] == "PASS" and d["findings"] == [] and isinstance(d["skipped"], list)
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: audit.json invalid protocol-v1 shape")
    echo "    FAIL: audit.json does not match protocol v1"
  fi
  # text mode remains default and unchanged
  (cd "$d" && bash harness/tools/audit-security.sh > audit.txt 2>/dev/null)
  PASS=$((PASS + 1))
  assert_grep "$t" "Security Audit Report" "$d/audit.txt"
  # unknown argument exits 2
  if (cd "$d" && bash harness/tools/audit-security.sh --bogus >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: --bogus should exit 2")
    echo "    FAIL: audit-security.sh accepted --bogus"
  else
    PASS=$((PASS + 1))
  fi
}

test_bench_json_output() {
  local t="bench.sh --json emits protocol v1 (record-only without framework)"
  run_test "$t"
  local d; d=$(new_project "bench-json")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=opencode --modules=performance-benchmarks >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: install failed"); return
  }
  PASS=$((PASS + 1))
  if (cd "$d" && bash harness/tools/bench.sh --json > bench.json 2>/dev/null); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: --json exited non-zero"); return
  fi
  if python3 - "$d/bench.json" <<'PYEOF' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
assert d["tool"] == "bench" and d["protocol"] == 1
assert d["stack"] == "python" and d["mode"] in ("run", "record-only")
assert d["results"] == [] and d["regressions"] == [] and d["verdict"] == "PASS"
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: bench.json invalid protocol-v1 shape")
    echo "    FAIL: bench.json does not match protocol v1"
  fi
}

test_scan_json_output() {
  local t="scan.py --json emits protocol v1 for summary and impact"
  run_test "$t"
  local d; d=$(new_project "scan-json")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=opencode --modules=project-scanner >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: install failed"); return
  }
  PASS=$((PASS + 1))
  mkdir -p "$d/core"
  cat > "$d/core/models.py" <<'EOF'
"""Domain models."""


class Order:
    """An order aggregate."""
EOF
  cat > "$d/core/service.py" <<'EOF'
"""Service layer."""
from core.models import Order


class OrderService:
    pass
EOF
  (cd "$d" && python3 harness/tools/scan.py --json --summary > summary.json) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: scan.py --json --summary failed"); return
  }
  PASS=$((PASS + 1))
  if python3 - "$d/summary.json" <<'PYEOF' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
assert d["tool"] == "scan" and d["protocol"] == 1 and d["command"] == "summary"
assert d["total_files"] == len(d["files"]) and "core/models.py" in d["files"]
assert d["high_risk"] == []
assert all("core/" not in f for fs in d["duplicates"].values() for f in fs)
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: summary.json invalid protocol-v1 shape")
    echo "    FAIL: summary.json does not match protocol v1"
  fi
  (cd "$d" && python3 harness/tools/scan.py --json --impact core/service.py > impact.json) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: scan.py --json --impact failed"); return
  }
  PASS=$((PASS + 1))
  if python3 - "$d/impact.json" <<'PYEOF' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
assert d["command"] == "impact" and d["file"] == "core/service.py"
assert "core/models.py" in d["dependencies"] and d["change_risk"] in ("HIGH", "MEDIUM", "LOW")
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: impact.json invalid protocol-v1 shape")
    echo "    FAIL: impact.json does not match protocol v1"
  fi
}

test_feature_list_validator() {
  local t="feature_list validator accepts fresh install and rejects invalid files"
  run_test "$t"
  local d; d=$(new_project "fl-validator")
  (cd "$d" && "$INIT" --tool=opencode >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: install failed"); return
  }
  PASS=$((PASS + 1))
  # fresh install validates clean (text mode)
  if (cd "$d" && python3 harness/tools/validate-feature-list.py harness/feature_list.json > validator.txt 2>&1); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: validator rejected a fresh feature_list.json")
    echo "    FAIL: validator rejected fresh install"
    return
  fi
  # machine mode: valid
  (cd "$d" && python3 harness/tools/validate-feature-list.py --json harness/feature_list.json > validator.json)
  PASS=$((PASS + 1))
  if python3 - "$d/validator.json" <<'PYEOF' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
assert d["tool"] == "validate-feature-list" and d["protocol"] == 1 and d["valid"] is True and d["errors"] == []
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: validator.json invalid for valid file")
    echo "    FAIL: validator.json wrong shape"
  fi
  # invalid: two in_progress + bad status
  cat > "$d/harness/feature_list.json" <<'EOF'
{
  "project": {"name": "p", "parallel": false, "modules": [], "audit_level": "basic"},
  "features": [
    {"id": 1, "name": "a", "title": "A", "description": "a", "acceptance": [], "status": "in_progress"},
    {"id": 2, "name": "b", "title": "B", "description": "b", "acceptance": [], "status": "in_progress"},
    {"id": 3, "name": "c", "title": "C", "description": "c", "acceptance": [], "status": "nope"}
  ]
}
EOF
  if (cd "$d" && python3 harness/tools/validate-feature-list.py harness/feature_list.json >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: validator accepted two in_progress + bad status")
    echo "    FAIL: validator too permissive"
  else
    PASS=$((PASS + 1))
  fi
  (cd "$d" && python3 harness/tools/validate-feature-list.py --json harness/feature_list.json > invalid.json)
  PASS=$((PASS + 1))
  assert_grep "$t" '"valid": false' "$d/invalid.json"
  # schema file exists in repo and parses
  if python3 -c "import json; json.load(open('$REPO_DIR/templates/feature_list.schema.json'))" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: feature_list.schema.json missing or invalid")
    echo "    FAIL: schema missing/invalid"
  fi
}

test_traceability_checker() {
  local t="traceability checker passes full coverage and flags missing R"
  run_test "$t"
  local d; d=$(new_project "trace-check")
  (cd "$d" && "$INIT" --tool=opencode >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: install failed"); return
  }
  PASS=$((PASS + 1))
  # fixture feature: requirements R1 R2, impl table covers only R1
  mkdir -p "$d/harness/specs/feat-a" "$d/tests"
  cat > "$d/harness/specs/feat-a/requirements.md" <<'EOF'
# Requirements — feat-a

- R1: WHEN the user submits an empty cart, the system SHALL show an error.
- R2: The system SHALL persist the order.
EOF
  cat > "$d/harness/progress/impl_session1.md" <<'EOF'
# Implementation — feat-a

| Requirement | Test(s)            | Implementation file(s) | Status |
|-------------|--------------------|------------------------|--------|
| R1          | test_empty_cart    | src/core/cart.py       | done   |
EOF
  cat > "$d/tests/test_cart.py" <<'EOF'
def test_empty_cart():
    assert True
EOF
  if [ ! -f "$d/harness/tools/check-traceability.py" ]; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: checker not installed")
    echo "    FAIL: harness/tools/check-traceability.py missing"
    return
  fi
  PASS=$((PASS + 1))
  if (cd "$d" && python3 harness/tools/check-traceability.py --feature feat-a > trace.txt 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: checker passed with R2 missing")
    echo "    FAIL: R2 gap not detected"
  else
    PASS=$((PASS + 1))
  fi
  assert_grep "$t" "R2" "$d/trace.txt"
  (cd "$d" && python3 harness/tools/check-traceability.py --feature feat-a --json > trace.json)
  PASS=$((PASS + 1))
  if python3 - "$d/trace.json" <<'PYEOF' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
assert d["tool"] == "check-traceability" and d["protocol"] == 1 and d["verdict"] == "FAIL"
feat = d["features"][0]
assert feat["name"] == "feat-a" and feat["requirements"] == 2 and feat["covered"] == 1
assert any(g["requirement"] == "R2" for g in feat["gaps"])
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: trace.json invalid shape")
    echo "    FAIL: trace.json wrong shape"
  fi
  # fix the table -> PASS (exit 0)
  cat > "$d/harness/progress/impl_session1.md" <<'EOF'
# Implementation — feat-a

| Requirement | Test(s)                      | Implementation file(s) | Status |
|-------------|------------------------------|------------------------|--------|
| R1          | test_empty_cart              | src/core/cart.py       | done   |
| R2          | test_empty_cart, test_persist| src/core/orders.py     | done   |
EOF
  cat >> "$d/tests/test_cart.py" <<'EOF'


def test_persist():
    assert True
EOF
  if (cd "$d" && python3 harness/tools/check-traceability.py --all --json > trace2.json 2>&1); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: checker failed after coverage completed")
    echo "    FAIL: complete coverage must pass"
  fi
  assert_grep "$t" '"verdict": "PASS"' "$d/trace2.json"
  # ghost test identifier must fail
  cat > "$d/harness/progress/impl_session1.md" <<'EOF'
| Requirement | Test(s)          | Implementation file(s) | Status |
|-------------|------------------|------------------------|--------|
| R1          | test_ghost       | src/core/cart.py       | done   |
| R2          | test_persist     | src/core/orders.py     | done   |
EOF
  if (cd "$d" && python3 harness/tools/check-traceability.py --feature feat-a >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: checker accepted ghost test identifier")
    echo "    FAIL: ghost test not detected"
  else
    PASS=$((PASS + 1))
  fi
  # unresolved semantics: covered row with status != done -> no gap, but unresolved
  cat > "$d/harness/progress/impl_session1.md" <<'EOF'
| Requirement | Test(s)          | Implementation file(s) | Status |
|-------------|------------------|------------------------|--------|
| R1          | test_empty_cart  | src/core/cart.py       | done   |
| R2          | test_persist     | src/core/orders.py     | wip    |
EOF
  if (cd "$d" && python3 harness/tools/check-traceability.py --feature feat-a --json > trace3.json); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: wip status row must not fail coverage")
    echo "    FAIL: wip status must not create a gap"
  fi
  if python3 - "$d/trace3.json" <<'PYEOF' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
feat = d["features"][0]
assert feat["gaps"] == [], feat["gaps"]
assert feat["unresolved"] == ["R2"], feat["unresolved"]
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: unresolved must be [\"R2\"] for wip row")
    echo "    FAIL: unresolved wrong shape"
  fi
}

test_evals_fixtures() {
  local t="evals fixtures: checker verdicts match EXPECTED outcomes"
  run_test "$t"
  if [ ! -d "$REPO_DIR/evals-fixtures" ]; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: evals-fixtures missing")
    echo "    FAIL: evals-fixtures does not exist"
    return
  fi
  PASS=$((PASS + 1))
  local d; d=$(new_project "evals-fx")
  (cd "$d" && "$INIT" --tool=opencode >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: install failed"); return
  }
  PASS=$((PASS + 1))
  # 01: full coverage -> PASS
  cp -r "$REPO_DIR/evals-fixtures/01-traceability-clean/project/." "$d/"
  if (cd "$d" && python3 harness/tools/check-traceability.py --feature feat-a --json > r1.json 2>&1); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: fixture 01 should PASS")
    echo "    FAIL: fixture 01 verdict"
  fi
  assert_grep "$t" '"verdict": "PASS"' "$d/r1.json"
  # 02: gap -> FAIL
  rm -rf "$d/harness" "$d/tests"
  (cd "$d" && "$INIT" --force --tool=opencode >/dev/null)
  cp -r "$REPO_DIR/evals-fixtures/02-traceability-gap/project/." "$d/"
  if (cd "$d" && python3 harness/tools/check-traceability.py --feature feat-a --json > r2.json 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: fixture 02 should FAIL")
    echo "    FAIL: fixture 02 verdict"
  else
    PASS=$((PASS + 1))
  fi
  assert_grep "$t" '"verdict": "FAIL"' "$d/r2.json"
  # 03: planted bug fixture is self-describing (structural check only)
  assert_file "$t" "$REPO_DIR/evals-fixtures/03-planted-security-bug/EXPECTED.md"
  assert_file "$t" "$REPO_DIR/evals-fixtures/03-planted-security-bug/project/src/core/db.py"
  assert_grep "$t" "REJECT" "$REPO_DIR/evals-fixtures/03-planted-security-bug/EXPECTED.md"
}

test_force_modules_replace_sections() {
  local t="--force with modules replaces injected sections and preserves user state"
  run_test "$t"
  local d; d=$(new_project "force-modules")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=claude --modules=security-audit,performance-benchmarks --audit-level=standard >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: first install failed"); return
  }
  PASS=$((PASS + 1))
  # simulate user state created after install
  echo '{"my_func": {"mean_ms": 12.5}}' > "$d/harness/baselines.json"
  mkdir -p "$d/harness/decisions"
  echo "# ADR-001" > "$d/harness/decisions/adr-001.md"
  (cd "$d" && "$INIT" --force --tool=claude --modules=security-audit,performance-benchmarks --audit-level=standard >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: force install failed"); return
  }
  PASS=$((PASS + 1))
  # sections replaced, not duplicated
  assert_count "$t" "harness:module:security-audit:start" "$d/docs/verification.md" 1
  assert_count "$t" "harness:module:performance-benchmarks:start" "$d/docs/verification.md" 1
  assert_count "$t" "harness:module:audit-checkpoint:start" "$d/harness/CHECKPOINTS.md" 1
  # user state preserved
  assert_grep "$t" '"my_func"' "$d/harness/baselines.json"
  assert_file "$t" "$d/harness/decisions/adr-001.md"
}

test_force_switch_modules_metadata() {
  local t="--force with a different module set refreshes feature_list metadata"
  run_test "$t"
  local d; d=$(new_project "force-switch-mods")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=opencode --modules=security-audit,performance-benchmarks --audit-level=strict >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: first install failed"); return
  }
  PASS=$((PASS + 1))
  (cd "$d" && "$INIT" --force --tool=opencode --modules=architecture-catalog --audit-level=basic >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: force install failed"); return
  }
  PASS=$((PASS + 1))
  # metadata refreshed to the new selection
  assert_grep "$t" '"architecture-catalog"' "$d/harness/feature_list.json"
  assert_count "$t" '"performance-benchmarks"' "$d/harness/feature_list.json" 0
  assert_grep "$t" '"audit_level": "basic"' "$d/harness/feature_list.json"
  # unselected append-section content is gone (base files re-copied clean, not re-injected)
  assert_count "$t" "harness:module:security-audit:start" "$d/docs/verification.md" 0
  assert_count "$t" "harness:module:audit-checkpoint:start" "$d/harness/CHECKPOINTS.md" 0
}

test_wekan_tickets_tool_dst() {
  local t="wekan-tickets installs the skill for the chosen tool and preserves config"
  run_test "$t"
  # claude variant
  local d; d=$(new_project "wekan-claude")
  (cd "$d" && "$INIT" --tool=claude --modules=wekan-tickets >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: claude install failed"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/.claude/skills/wekan-tasks/SKILL.md"
  assert_no_file "$t" "$d/.opencode/skill/wekan-tasks/SKILL.md"
  assert_file "$t" "$d/harness/wekan.json"
  if python3 - "$d/harness/wekan.json" <<'PYEOF' >/dev/null 2>&1; then
import json, sys
raw = open(sys.argv[1]).read()
data = json.loads(raw)
for key in ("url", "list_map", "credentials_file", "enabled"):
    assert key in data, f"missing key: {key}"
assert "WEKAN_API_BEARER_TOKEN" not in raw, "secrets must not be in wekan.json"
assert "WEKAN_API_USER_ID" not in raw, "secrets must not be in wekan.json"
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: wekan.json invalid or contains secrets")
    echo "    FAIL: wekan.json invalid or contains secrets"
  fi
  # preserved as user state under --force
  echo '{"custom": true}' > "$d/harness/wekan.json"
  (cd "$d" && "$INIT" --force --tool=claude --modules=wekan-tickets >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: force install failed"); return
  }
  PASS=$((PASS + 1))
  assert_grep "$t" '"custom": true' "$d/harness/wekan.json"
  assert_file "$t" "$d/.claude/skills/wekan-tasks/SKILL.md"
  # opencode variant
  local d2; d2=$(new_project "wekan-opencode")
  (cd "$d2" && "$INIT" --tool=opencode --modules=wekan-tickets >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: opencode install failed"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d2/.opencode/skill/wekan-tasks/SKILL.md"
  assert_no_file "$t" "$d2/.claude/skills/wekan-tasks/SKILL.md"
}

# ── Main ───────────────────────────────────────────────
TMP_ROOT="$(mktemp -d /tmp/opencode/harness-test-XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

test_claude_mode_typescript
test_opencode_mode_generic
test_interactive_prompt
test_invalid_tool_rejected
test_interactive_module_menu
test_reinstall_refused
test_force_reinstall_preserves_state
test_force_switch_tool
test_verify_script_runs
test_python_stack
test_module_manifests_valid
test_modules_install
test_default_install_no_modules
test_invalid_module_rejected
test_invalid_audit_level_rejected
test_module_filtered_by_stack
test_project_scanner_module
test_security_audit_module
test_modules_install_strict
test_audit_json_output
test_bench_json_output
test_scan_json_output
test_feature_list_validator
test_traceability_checker
test_evals_fixtures
test_force_modules_replace_sections
test_wekan_tickets_tool_dst
test_force_switch_modules_metadata

echo ""
echo "────────────────────────────────────────"
echo "PASS: $PASS  FAIL: $FAIL"
if [ $FAIL -gt 0 ]; then
  printf 'Failed:\n'
  printf '  - %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
