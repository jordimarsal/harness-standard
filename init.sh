#!/usr/bin/env bash
# init.sh — Install the standardized harness into a project
#
# Usage: cd /path/to/your/project && /path/to/harness-standard/init.sh [--tool=claude|opencode] [--modules=m1,m2] [--audit-level=basic|standard|strict] [--force]
#
# Detects tech stack, asks which AI tool drives the harness (claude / opencode),
# copies templates and adapts configuration.
#
# Destination layout:
#   - Entry point (CLAUDE.md or AGENTS.md) at the project root
#   - Tool directory (.claude/ or .opencode/) at the project root
#   - docs/ at the project root
#   - Everything else grouped under harness/
#
# Safe: refuses to overwrite an existing harness. Use --force to reinstall:
# it refreshes templates but preserves user state (harness/feature_list.json,
# harness/progress/, harness/specs/, docs/architecture.md, docs/conventions.md).

set -euo pipefail

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }
info() { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }

# ── Locate harness templates ───────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [ ! -d "$TEMPLATES_DIR" ]; then
  fail "Templates directory not found at $TEMPLATES_DIR"
  exit 1
fi

# ── Tool / modules / audit-level selection ─────────────
TOOL=""
FORCE=0
MODULES_FLAG=""
AUDIT_LEVEL=""
for arg in "$@"; do
  case "$arg" in
    --tool=claude)   TOOL="claude" ;;
    --tool=opencode) TOOL="opencode" ;;
    --force) FORCE=1 ;;
    --modules=*)     MODULES_FLAG="${arg#--modules=}" ;;
    --audit-level=*) AUDIT_LEVEL="${arg#--audit-level=}" ;;
    *)
      fail "Unknown argument: $arg"
      fail "Usage: init.sh [--tool=claude|opencode] [--modules=m1,m2] [--audit-level=basic|standard|strict] [--force]"
      exit 1
      ;;
  esac
done

if [ -n "$AUDIT_LEVEL" ]; then
  case "$AUDIT_LEVEL" in
    basic|standard|strict) ;;
    *)
      fail "Invalid --audit-level value: $AUDIT_LEVEL (use basic|standard|strict)"
      exit 1
      ;;
  esac
fi

if [ -z "$TOOL" ]; then
  echo ""
  echo "Which AI tool will drive this harness?"
  echo "  [c]laude    — Claude Code (generates CLAUDE.md + .claude/)"
  echo "  [o]pencode  — opencode   (generates AGENTS.md + .opencode/)"
  while [ -z "$TOOL" ]; do
    printf "Choice [c/o]: "
    read -r answer
    case "$answer" in
      c|claude)   TOOL="claude" ;;
      o|opencode) TOOL="opencode" ;;
      *) warn "Please answer 'c' (claude) or 'o' (opencode)." ;;
    esac
  done
fi
info "Tool: $TOOL"

# ── Check existing harness ─────────────────────────────
if [ "$FORCE" -eq 1 ]; then
  info "Force reinstall: refreshing templates."
  info "Preserved if present: harness/feature_list.json, harness/progress/, harness/specs/, docs/architecture.md, docs/conventions.md"
  rm -rf .claude .opencode
  rm -f CLAUDE.md AGENTS.md opencode.json
elif [ -d "harness" ] || [ -f "CLAUDE.md" ] || [ -f "AGENTS.md" ] || [ -d ".claude" ] || [ -d ".opencode" ]; then
  fail "A harness is already installed in this directory (harness/, CLAUDE.md, AGENTS.md, .claude/ or .opencode/ exists)."
  fail "Remove existing harness files before reinstalling, or use --force to reinstall (keeps user state)."
  exit 1
fi

# ── Stack detection ────────────────────────────────────
detect_stack() {
  # Priority: TypeScript > Node > Android > Java > Python > Rust > Generic
  if [ -f "tsconfig.json" ]; then
    echo "typescript"
    return
  fi
  if [ -f "package.json" ]; then
    echo "node"
    return
  fi
  if [ -f "build.gradle" ] && [ -f "AndroidManifest.xml" -o -f "app/src/main/AndroidManifest.xml" ]; then
    echo "android"
    return
  fi
  if [ -f "build.gradle" ] || [ -f "pom.xml" ]; then
    echo "java"
    return
  fi
  if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    echo "python"
    return
  fi
  if [ -f "Cargo.toml" ]; then
    echo "rust"
    return
  fi
  echo "generic"
}

STACK=$(detect_stack)
info "Detected stack: $STACK"

# ── Module manifest helpers (pure sed/grep; manifests follow a strict format) ──
manifest_str() {  # manifest_str <manifest> <key> — value of a "key": "value" line
  sed -n "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -n 1
}

manifest_list() {  # manifest_list <manifest> <key> — items of a one-line string array
  { grep -E "^[[:space:]]*\"$2\"" "$1" || true; } \
    | { grep -o '"[^"]*"' || true; } \
    | { grep -vx "\"$2\"" || true; } \
    | sed 's/^"//; s/"$//'
}

manifest_injects() {  # manifest_injects <manifest> — one inject entry per line
  grep -E '^[[:space:]]*\{[[:space:]]*"src"' "$1" || true
}

module_supports_stack() {  # module_supports_stack <module> <stack> → exit 0 if supported
  { grep -E "^[[:space:]]*\"stacks\"" "$TEMPLATES_DIR/modules/$1/manifest.json" || true; } \
    | grep -q "\"$2\""
}

# ── Optional capability modules ────────────────────────
MODULES_SELECTED=()

MODULES_AVAILABLE=()
for mdir in "$TEMPLATES_DIR/modules"/*/; do
  [ -f "$mdir/manifest.json" ] || continue
  MODULES_AVAILABLE+=("$(basename "$mdir")")
done

if [ -n "$MODULES_FLAG" ]; then
  IFS=',' read -ra requested <<< "$MODULES_FLAG"
  for m in "${requested[@]}"; do
    m="$(printf '%s' "$m" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [ -z "$m" ]; then continue; fi
    if [ ! -f "$TEMPLATES_DIR/modules/$m/manifest.json" ]; then
      fail "Unknown module: $m"
      fail "Available: ${MODULES_AVAILABLE[*]:-none}"
      exit 1
    fi
    if module_supports_stack "$m" "$STACK"; then
      MODULES_SELECTED+=("$m")
    else
      warn "Module '$m' does not support stack '$STACK' — skipped."
    fi
  done
else
  # Mandatory interactive menu (§4.2): every module is always presented.
  echo ""
  echo "Optional capability modules (none are installed by default):"
  menu_i=1
  for m in "${MODULES_AVAILABLE[@]:+${MODULES_AVAILABLE[@]}}"; do
    mf="$TEMPLATES_DIR/modules/$m/manifest.json"
    desc="$(manifest_str "$mf" "description")"
    if module_supports_stack "$m" "$STACK"; then
      mark=""
    else
      mark="  [incompatible with stack: $STACK — will be skipped]"
    fi
    printf "  %d) %-24s %s%s\n" "$menu_i" "$m" "$desc" "$mark"
    MENU_MAP[$menu_i]="$m"
    menu_i=$((menu_i + 1))
  done
  printf "Select modules to install (comma-separated numbers, Enter = none): "
  read -r answer || answer=""
  if [ -n "$answer" ]; then
    IFS=',' read -ra nums <<< "$answer"
    for n in "${nums[@]}"; do
      n="$(printf '%s' "$n" | tr -d '[:space:]')"
      if [ -z "$n" ]; then continue; fi
      m="${MENU_MAP[$n]:-}"
      if [ -z "$m" ]; then
        warn "Ignoring invalid module number: $n"
      elif module_supports_stack "$m" "$STACK"; then
        MODULES_SELECTED+=("$m")
      else
        warn "Module '$m' does not support stack '$STACK' — skipped."
      fi
    done
  fi
fi

# Audit level prompt (skipped when --audit-level was given).
if [ -z "$AUDIT_LEVEL" ]; then
  echo ""
  echo "Audit level applied by the reviewer (when audit modules are installed):"
  echo "  1) basic    — checklist-only review (default)"
  echo "  2) standard — run harness/tools/audit-security.sh on every review"
  echo "  3) strict   — standard + benchmark comparison vs harness/baselines.json"
  printf "Choice [1/2/3, Enter = basic]: "
  read -r answer || answer=""
  case "$answer" in
    ""|1|basic) AUDIT_LEVEL="basic" ;;
    2|standard) AUDIT_LEVEL="standard" ;;
    3|strict)   AUDIT_LEVEL="strict" ;;
    *)
      warn "Invalid audit level '$answer'; using 'basic'."
      AUDIT_LEVEL="basic"
      ;;
  esac
fi

AUDIT_LEVEL="${AUDIT_LEVEL:-basic}"

# ── Stack-specific variables ───────────────────────────
case "$STACK" in
  typescript)
    TEST_CMD="npx vitest run"
    BUILD_CMD="npx tsc"
    ;;
  node)
    TEST_CMD="npm test"
    BUILD_CMD="npm run build"
    ;;
  android)
    TEST_CMD="./gradlew test"
    BUILD_CMD="./gradlew assembleDebug"
    ;;
  java)
    if [ -f "build.gradle" ]; then
      TEST_CMD="./gradlew test"
      BUILD_CMD="./gradlew build"
    else
      TEST_CMD="mvn test"
      BUILD_CMD="mvn package"
    fi
    ;;
  python)
    TEST_CMD="python3 -m pytest -q tests"
    BUILD_CMD="echo 'no build step for python'"
    ;;
  rust)
    TEST_CMD="cargo test"
    BUILD_CMD="cargo build"
    ;;
  generic)
    TEST_CMD="echo 'configure test command'"
    BUILD_CMD="echo 'configure build command'"
    ;;
esac

PROJECT_NAME="$(basename "$(pwd)")"

# ── Module injection ───────────────────────────────────
inject_append_section() {  # inject_append_section <dst> <module-name> <src-file>
  local dst="$1" name="$2" src="$3"
  local start end tmp
  start="<!-- harness:module:$name:start -->"
  end="<!-- harness:module:$name:end -->"
  mkdir -p "$(dirname "$dst")"
  if [ ! -f "$dst" ]; then : > "$dst"; fi
  if grep -qF "$start" "$dst"; then
    # Replace only this module's own section (idempotent under --force).
    tmp="$(mktemp)"
    chmod 644 "$tmp"
    awk -v start="$start" -v end="$end" -v src="$src" '
      BEGIN { while ((getline line < src) > 0) repl = repl line "\n" }
      index($0, start) { printf "%s\n%s", $0, repl; inblk = 1; next }
      inblk && index($0, end) { inblk = 0 }
      !inblk { print }
    ' "$dst" > "$tmp" && mv "$tmp" "$dst"
  else
    { printf '\n'; printf '%s\n' "$start"; cat "$src"; printf '%s\n' "$end"; } >> "$dst"
  fi
}

inject_module() {  # inject_module <module-name>
  local m="$1"
  local mdir="$TEMPLATES_DIR/modules/$m"
  local line src dst mode
  while IFS= read -r line; do
    if [ -z "$line" ]; then continue; fi
    src=$(printf '%s\n' "$line" | sed -n 's/.*"src"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    mode=$(printf '%s\n' "$line" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if printf '%s\n' "$line" | grep -q '"dst"[[:space:]]*:[[:space:]]*{'; then
      # Tool-dependent destination, resolved with the chosen tool.
      dst=$(printf '%s\n' "$line" | sed -n "s/.*\"$TOOL\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")
    else
      dst=$(printf '%s\n' "$line" | sed -n 's/.*"dst"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    fi
    case "$mode" in
      copy)
        mkdir -p "$(dirname "$dst")"
        cp "$mdir/$src" "$dst"
        case "$src" in *.sh) chmod +x "$dst" ;; esac
        ;;
      copy-if-missing)
        if [ ! -f "$dst" ]; then
          mkdir -p "$(dirname "$dst")"
          cp "$mdir/$src" "$dst"
        fi
        ;;
      append-section)
        inject_append_section "$dst" "$m" "$mdir/$src"
        ;;
      *)
        fail "Unknown inject mode '$mode' in module $m"
        exit 1
        ;;
    esac
  done < <(manifest_injects "$mdir/manifest.json")
}

refresh_project_metadata() {  # refresh_project_metadata <feature-list>
  # Best-effort: --force records the current run's module/audit selection.
  # The target lines have the exact shape the installer itself writes, so a
  # line-scoped sed is safe; any other shape only warns.
  local fl="$1"
  if grep -q '"modules"[[:space:]]*:' "$fl"; then
    sed "s|\"modules\"[[:space:]]*:[[:space:]]*\[[^]]*\]|\"modules\": [$MODULES_JSON]|" "$fl" > "$fl.tmp" && mv "$fl.tmp" "$fl"
  else
    warn "Could not update 'modules' in $fl — set it manually in the project section."
  fi
  if grep -q '"audit_level"[[:space:]]*:' "$fl"; then
    sed "s|\"audit_level\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"audit_level\": \"$AUDIT_LEVEL\"|" "$fl" > "$fl.tmp" && mv "$fl.tmp" "$fl"
  else
    warn "Could not update 'audit_level' in $fl — set it manually in the project section."
  fi
}

# ── Copy templates ─────────────────────────────────────
info "Installing harness templates..."

# docs/ stays at the project root
mkdir -p docs
cp "$TEMPLATES_DIR/docs/specs.md" ./docs/specs.md
cp "$TEMPLATES_DIR/docs/verification.md" ./docs/verification.md

if [ ! -f "docs/architecture.md" ]; then
  sed -e "s|{{ARCHITECTURE_PRINCIPLES}}|Define the architectural principles for this project here.|g" \
      -e "s|{{DATA_FLOW}}|Describe the data flow here.|g" \
      -e "s|{{ARCHITECTURE_DONT}}|List what NOT to do here.|g" \
      "$TEMPLATES_DIR/docs/architecture.md.tpl" > docs/architecture.md
fi

if [ ! -f "docs/conventions.md" ]; then
  sed -e "s|{{STYLE_RULES}}|Define coding style rules here.|g" \
      -e "s|{{NAMING_RULES}}|Define naming conventions here.|g" \
      -e "s|{{FILE_STRUCTURE}}|Define file structure rules here.|g" \
      -e "s|{{TEST_RULES}}|Define testing rules here.|g" \
      -e "s|{{ERROR_HANDLING}}|Define error handling rules here.|g" \
      "$TEMPLATES_DIR/docs/conventions.md.tpl" > docs/conventions.md
fi

# Everything else groups under harness/
mkdir -p harness/progress harness/specs
cp "$TEMPLATES_DIR/CHECKPOINTS.md" ./harness/CHECKPOINTS.md
[ -f "./harness/progress/current.md" ] || cp "$TEMPLATES_DIR/progress/current.md" ./harness/progress/current.md
[ -f "./harness/progress/history.md" ] || cp "$TEMPLATES_DIR/progress/history.md" ./harness/progress/history.md

MODULES_JSON=""
if [ "${#MODULES_SELECTED[@]}" -gt 0 ]; then
  for m in "${MODULES_SELECTED[@]}"; do
    MODULES_JSON="${MODULES_JSON:+$MODULES_JSON, }\"$m\""
  done
fi

if [ ! -f "harness/feature_list.json" ]; then
  sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
      -e "s|{{MODULES}}|$MODULES_JSON|g" \
      -e "s|{{AUDIT_LEVEL}}|$AUDIT_LEVEL|g" \
      "$TEMPLATES_DIR/feature_list.json" > harness/feature_list.json
else
  ok "Keeping existing harness/feature_list.json"
  refresh_project_metadata "harness/feature_list.json"
fi

# Verification script becomes harness/init.sh
cp "$SCRIPT_DIR/init-verify.sh" ./harness/init.sh
chmod +x ./harness/init.sh

# Tool-specific files at the project root
if [ "$TOOL" = "claude" ]; then
  mkdir -p .claude/agents
  for agent in leader spec-author implementer reviewer; do
    cp "$TEMPLATES_DIR/.claude/agents/${agent}.md" ".claude/agents/${agent}.md"
  done

  sed -e "s|{{TEST_CMD}}|$TEST_CMD|g" \
      -e "s|{{BUILD_CMD}}|$BUILD_CMD|g" \
      "$TEMPLATES_DIR/.claude/settings.json" > .claude/settings.json

  if [ -f "$TEMPLATES_DIR/stacks/$STACK/CLAUDE.md.tpl" ]; then
    cp "$TEMPLATES_DIR/stacks/$STACK/CLAUDE.md.tpl" ./CLAUDE.md
  else
    cp "$TEMPLATES_DIR/stacks/generic/CLAUDE.md.tpl" ./CLAUDE.md
  fi
else
  mkdir -p .opencode/agent
  for agent in leader spec-author implementer reviewer; do
    cp "$TEMPLATES_DIR/.opencode/agent/${agent}.md" ".opencode/agent/${agent}.md"
  done

  sed -e "s|{{TEST_CMD}}|$TEST_CMD|g" \
      -e "s|{{BUILD_CMD}}|$BUILD_CMD|g" \
      "$TEMPLATES_DIR/opencode.json" > opencode.json

  cp "$TEMPLATES_DIR/AGENTS.md" ./AGENTS.md
fi

ok "Templates installed"

# ── Inject optional modules ────────────────────────────
if [ "${#MODULES_SELECTED[@]}" -gt 0 ]; then
  info "Injecting modules..."
  for m in "${MODULES_SELECTED[@]}"; do
    inject_module "$m"
  done
  C7_DONE=0
  for m in "${MODULES_SELECTED[@]}"; do
    case "$m" in
      security-audit|performance-benchmarks)
        if [ "$C7_DONE" -eq 0 ]; then
          inject_append_section "./harness/CHECKPOINTS.md" "audit-checkpoint" \
            "$TEMPLATES_DIR/modules/_shared/c7-audit.md"
          C7_DONE=1
        fi
        ;;
    esac
  done
  info "Modules installed: ${MODULES_SELECTED[*]}"
fi
if [ "$AUDIT_LEVEL" != "basic" ]; then
  info "Audit level: $AUDIT_LEVEL"
fi

# ── Validation ─────────────────────────────────────────
echo ""
echo "── Validation ──────────────────────────────────────────"

EXIT_CODE=0

check_file() {
  if [ ! -f "$1" ]; then
    fail "Missing file: $1"
    EXIT_CODE=1
  else
    ok "Exists $1"
  fi
}

check_dir() {
  if [ ! -d "$1" ]; then
    fail "Missing directory: $1"
    EXIT_CODE=1
  else
    ok "Exists $1"
  fi
}

if [ "$TOOL" = "claude" ]; then
  check_file "CLAUDE.md"
  check_file ".claude/settings.json"
  for a in leader spec-author implementer reviewer; do
    check_file ".claude/agents/${a}.md"
  done
else
  check_file "AGENTS.md"
  check_file "opencode.json"
  for a in leader spec-author implementer reviewer; do
    check_file ".opencode/agent/${a}.md"
  done
fi

check_file "harness/CHECKPOINTS.md"
check_file "harness/feature_list.json"
check_file "harness/init.sh"
check_file "harness/progress/current.md"
check_file "harness/progress/history.md"
check_file "docs/architecture.md"
check_file "docs/conventions.md"
check_file "docs/specs.md"
check_file "docs/verification.md"
check_dir "harness/specs"

for m in "${MODULES_SELECTED[@]:+${MODULES_SELECTED[@]}}"; do
  while IFS= read -r vpath; do
    if [ -z "$vpath" ]; then continue; fi
    check_file "$vpath"
  done < <(manifest_list "$TEMPLATES_DIR/modules/$m/manifest.json" "verify")
done

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  ok "Harness installed successfully for stack: $STACK (tool: $TOOL)"
  echo ""
  info "Next steps:"
  info "  1. Edit docs/architecture.md with your project's architecture."
  info "  2. Edit docs/conventions.md with your project's coding conventions."
  info "  3. Add features to harness/feature_list.json."
  if [ "$TOOL" = "claude" ]; then
    info "  4. Start Claude Code and let the leader agent guide you."
  else
    info "  4. Start opencode and let the leader agent guide you."
  fi
else
  fail "Harness installation incomplete. Resolve errors above."
fi

exit $EXIT_CODE
