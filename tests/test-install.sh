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
  assert_no_dir "$t" "$d/harness/tools"
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
