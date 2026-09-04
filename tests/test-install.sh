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

echo ""
echo "────────────────────────────────────────"
echo "PASS: $PASS  FAIL: $FAIL"
if [ $FAIL -gt 0 ]; then
  printf 'Failed:\n'
  printf '  - %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
