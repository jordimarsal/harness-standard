#!/usr/bin/env bash
# init.sh — Install the standardized harness into a project
#
# Usage: cd /path/to/your/project && /path/to/harness-standard/init.sh [--tool=claude|opencode] [--modules=m1,m2] [--audit-level=basic|standard|strict] [--force] [--update] [--architecture=<name>] [--add-modules=m1,m2] [--remove-modules=m1,m2]
#
# Detects tech stack, asks which AI tool drives the harness (claude / opencode),
# copies templates and adapts configuration.
#
# Conventions and architecture docs:
#   docs/conventions.md is generated from the detected stack's language
#   conventions plus the chosen architecture section; docs/architecture.md is
#   the chosen architecture's template (--architecture=<name>, or interactive
#   on a TTY at install). Existing files are regenerated only when
#   installer-generated (byte-identical) or when --architecture is given.
#
# Safe: refuses to overwrite an existing harness. Use --force to reinstall:
# it refreshes templates but preserves user state (harness/feature_list.json,
# harness/progress/, harness/specs/, docs/architecture.md, docs/conventions.md).
# Use --update instead: it reuses the stored tool/modules/audit configuration,
# never drops modules, and can add (--add-modules) or remove (--remove-modules)
# modules at any time.

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

# Harness version: git tag (or tag-distance/SHA) of the templates checkout,
# else the first release heading in the CHANGELOG (skips "Unreleased"), else dev.
resolve_harness_version() {
  local v=""
  if command -v git >/dev/null 2>&1; then
    v="$(git -C "$SCRIPT_DIR" describe --tags --always 2>/dev/null || true)"
  fi
  if [ -z "$v" ]; then
    v="$(sed -n 's/^## \(v[0-9][0-9A-Za-z.]*\).*/\1/p' "$TEMPLATES_DIR/CHANGELOG.md" 2>/dev/null | head -n 1)"
  fi
  printf '%s' "${v:-dev}"
}
HARNESS_VERSION="$(resolve_harness_version)"

if [ ! -d "$TEMPLATES_DIR" ]; then
  fail "Templates directory not found at $TEMPLATES_DIR"
  exit 1
fi

# ── Tool / modules / audit-level selection ─────────────
TOOL=""
FORCE=0
UPDATE=0
FORCE_SOURCE=""
MODULES_FLAG=""
ADD_MODULES_FLAG=""
REMOVE_MODULES_FLAG=""
ARCH_FLAG=""
REMOVED_MODULES=()
AUDIT_LEVEL=""
for arg in "$@"; do
  case "$arg" in
    --tool=claude)   TOOL="claude" ;;
    --tool=opencode) TOOL="opencode" ;;
    --force) FORCE=1 ;;
    --update) UPDATE=1 ;;
    --modules=*)     MODULES_FLAG="${arg#--modules=}" ;;
    --add-modules=*) ADD_MODULES_FLAG="${arg#--add-modules=}" ;;
    --remove-modules=*) REMOVE_MODULES_FLAG="${arg#--remove-modules=}" ;;
    --architecture=*) ARCH_FLAG="${arg#--architecture=}" ;;
    --audit-level=*) AUDIT_LEVEL="${arg#--audit-level=}" ;;
    *)
      fail "Unknown argument: $arg"
      fail "Usage: init.sh [--tool=claude|opencode] [--modules=m1,m2] [--audit-level=basic|standard|strict] [--force] [--update] [--architecture=<name>] [--add-modules=m1,m2] [--remove-modules=m1,m2]"
      exit 1
      ;;
  esac
done

if { [ -n "$ADD_MODULES_FLAG" ] || [ -n "$REMOVE_MODULES_FLAG" ]; } && [ "$UPDATE" -eq 0 ]; then
  fail "--add-modules/--remove-modules require --update."
  exit 1
fi

if [ "$FORCE" -eq 1 ] && [ "$UPDATE" -eq 1 ]; then
  fail "Use --update or --force, not both."
  exit 1
fi

if [ -n "$AUDIT_LEVEL" ]; then
  case "$AUDIT_LEVEL" in
    basic|standard|strict) ;;
    *)
      fail "Invalid --audit-level value: $AUDIT_LEVEL (use basic|standard|strict)"
      exit 1
      ;;
  esac
fi

# ── --update: preload stored config from the installed harness ──
# Reads tool/modules/audit level from the project itself; flags still override.
# Absence never drops anything (unlike --force, which re-asks from scratch).
if [ "$UPDATE" -eq 1 ]; then
  if [ ! -f "harness/feature_list.json" ]; then
    fail "No harness installed here — nothing to update. Install first."
    exit 1
  fi
  OLD_VERSION="$(sed -n 's/.*"harness_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' harness/feature_list.json | head -n 1)"
  OLD_VERSION="${OLD_VERSION:-unknown (pre-versioning install)}"
  if [ -z "$TOOL" ]; then
    if [ -f "CLAUDE.md" ]; then
      TOOL="claude"
    elif [ -f "AGENTS.md" ]; then
      TOOL="opencode"
    else
      fail "Cannot detect the driving tool (no CLAUDE.md or AGENTS.md at the root). Pass --tool=claude|opencode."
      exit 1
    fi
  fi
  if [ -z "$MODULES_FLAG" ]; then
    MODULES_FLAG="$(sed -n 's/.*"modules"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' harness/feature_list.json | head -n 1 | tr -d '"[:space:]')"
    if [ -n "$MODULES_FLAG" ]; then
      info "Update: re-applying stored modules: $(printf '%s' "$MODULES_FLAG" | tr ',' ' ')"
    fi
  fi
  if [ -n "$ADD_MODULES_FLAG" ] || [ -n "$REMOVE_MODULES_FLAG" ]; then
    MOD_LIST=()
    if [ -n "$MODULES_FLAG" ]; then
      IFS=',' read -ra _parts <<< "$MODULES_FLAG"
      for _p in "${_parts[@]}"; do
        _p="$(printf '%s' "$_p" | tr -d '[:space:]')"
        [ -n "$_p" ] && MOD_LIST+=("$_p")
      done
    fi
    if [ -n "$ADD_MODULES_FLAG" ]; then
      IFS=',' read -ra _parts <<< "$ADD_MODULES_FLAG"
      for _p in "${_parts[@]}"; do
        _p="$(printf '%s' "$_p" | tr -d '[:space:]')"
        [ -z "$_p" ] && continue
        _dup=0
        for _e in "${MOD_LIST[@]:+${MOD_LIST[@]}}"; do [ "$_e" = "$_p" ] && _dup=1; done
        [ "$_dup" -eq 0 ] && MOD_LIST+=("$_p")
      done
    fi
    REMOVED_MODULES=()
    if [ -n "$REMOVE_MODULES_FLAG" ]; then
      IFS=',' read -ra _parts <<< "$REMOVE_MODULES_FLAG"
      _keep=()
      for _e in "${MOD_LIST[@]:+${MOD_LIST[@]}}"; do
        _drop=0
        for _p in "${_parts[@]}"; do
          _p="$(printf '%s' "$_p" | tr -d '[:space:]')"
          [ "$_e" = "$_p" ] && _drop=1
        done
        if [ "$_drop" -eq 1 ]; then REMOVED_MODULES+=("$_e"); else _keep+=("$_e"); fi
      done
      MOD_LIST=("${_keep[@]:+${_keep[@]}}")
    fi
    MODULES_FLAG="$(IFS=,; printf '%s' "${MOD_LIST[*]}")"
  fi
  if [ -z "$AUDIT_LEVEL" ]; then
    AUDIT_LEVEL="$(sed -n 's/.*"audit_level"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' harness/feature_list.json | head -n 1)"
    case "$AUDIT_LEVEL" in
      basic|standard|strict) ;;
      "") AUDIT_LEVEL="basic" ;;
      *)
        fail "Stored audit_level '$AUDIT_LEVEL' is invalid — fix harness/feature_list.json or pass --audit-level=basic|standard|strict."
        exit 1
        ;;
    esac
  fi
  FORCE=1
  FORCE_SOURCE="update"
fi

# Interactive prompts require a TTY (curl pipes and CI have none).
# HARNESS_FORCE_TTY=1 forces them (used by the test suite).
is_interactive() { [ -t 0 ] || [ "${HARNESS_FORCE_TTY:-0}" = "1" ]; }

if [ -z "$TOOL" ]; then
  if is_interactive; then
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
  else
    warn "No TTY detected — defaulting to tool 'claude'. Pass --tool=claude|opencode to choose."
    TOOL="claude"
  fi
fi
info "Tool: $TOOL"

# ── Check existing harness ─────────────────────────────
if [ "$FORCE" -eq 1 ]; then
  if [ "$FORCE_SOURCE" = "update" ]; then
    if [ "$OLD_VERSION" = "$HARNESS_VERSION" ]; then
      info "Update: same version ($HARNESS_VERSION) — repairing harness-managed files."
    else
      info "Updating harness: $OLD_VERSION -> $HARNESS_VERSION"
    fi
  else
    info "Force reinstall: refreshing templates."
  fi
  info "Preserved if present: harness/feature_list.json, harness/progress/, harness/specs/, docs/architecture.md, docs/conventions.md"
  rm -rf .claude/agents .opencode/agent .claude/skills/wekan-tasks .opencode/skill/wekan-tasks
  rm -f CLAUDE.md AGENTS.md opencode.json .claude/settings.json
  if [ -d .claude ] && [ -z "$(ls -A .claude 2>/dev/null)" ]; then rmdir .claude; fi
  if [ -d .opencode ] && [ -z "$(ls -A .opencode 2>/dev/null)" ]; then rmdir .opencode; fi
  if [ -d .claude ]; then
    warn "Keeping non-harness files in .claude/: $(find .claude -mindepth 1 -maxdepth 1 -exec basename {} + 2>/dev/null | tr '\n' ' ')"
  fi
  if [ -d .opencode ]; then
    warn "Keeping non-harness files in .opencode/: $(find .opencode -mindepth 1 -maxdepth 1 -exec basename {} + 2>/dev/null | tr '\n' ' ')"
  fi
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
  if [ -f "build.gradle" ] && { [ -f "AndroidManifest.xml" ] || [ -f "app/src/main/AndroidManifest.xml" ]; }; then
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

# Selectable architectures: the directory is the catalog.
ARCHITECTURES_AVAILABLE=()
for adir in "$TEMPLATES_DIR/architectures"/*/; do
  [ -f "$adir/architecture.md" ] || continue
  ARCHITECTURES_AVAILABLE+=("$(basename "$adir")")
done
if [ -n "$ARCH_FLAG" ]; then
  _known=0
  for _a in "${ARCHITECTURES_AVAILABLE[@]:+${ARCHITECTURES_AVAILABLE[@]}}"; do
    [ "$_a" = "$ARCH_FLAG" ] && _known=1
  done
  if [ "$_known" -eq 0 ]; then
    fail "Unknown architecture: $ARCH_FLAG"
    fail "Available: ${ARCHITECTURES_AVAILABLE[*]:-none}"
    exit 1
  fi
fi

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
  if is_interactive; then
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
      MENU_MAP[menu_i]="$m"
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
  else
    info "No TTY detected — no optional modules installed. Pass --modules=m1,m2 to select."
  fi
fi

# Architecture picker (fresh installs on a TTY; --update uses --architecture=).
ARCH_MAP=()
if [ -z "$ARCH_FLAG" ] && is_interactive && [ "$UPDATE" -eq 0 ]; then
  echo ""
  echo "Architecture for docs/architecture.md (Enter = generic template):"
  _ai=1
  for _a in "${ARCHITECTURES_AVAILABLE[@]:+${ARCHITECTURES_AVAILABLE[@]}}"; do
    printf "  %d) %s\n" "$_ai" "$_a"
    ARCH_MAP[_ai]="$_a"
    _ai=$((_ai + 1))
  done
  printf "Select architecture (number, Enter = skip): "
  read -r answer || answer=""
  if [ -n "$answer" ]; then
    _pick="${ARCH_MAP[$answer]:-}"
    if [ -n "$_pick" ]; then
      ARCH_FLAG="$_pick"
    else
      warn "Ignoring invalid architecture number: $answer"
    fi
  fi
fi

# Audit level prompt (skipped when --audit-level was given).
if [ -z "$AUDIT_LEVEL" ]; then
  if is_interactive; then
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
  else
    AUDIT_LEVEL="basic"
  fi
fi

AUDIT_LEVEL="${AUDIT_LEVEL:-basic}"

# ── Stack-specific variables ───────────────────────────
case "$STACK" in
  typescript)
    TEST_CMD="npx --no-install vitest run"
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
    if command -v uv >/dev/null 2>&1 && [ -f "uv.lock" ]; then
      TEST_CMD="uv run pytest tests"
    else
      TEST_CMD="python3 -m pytest -q tests"
    fi
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
# Derived strings must be data, never sed program text.
case "$PROJECT_NAME" in
  ""|*[!A-Za-z0-9._\ -]*)
    warn "Directory name contains characters unsafe for template rendering; using 'project' as project name."
    PROJECT_NAME="project"
    ;;
esac

# ── Module injection ───────────────────────────────────
# ── Install-time write confinement ─────────────────────
assert_inside_project() {  # assert_inside_project <path>
  local p="$1"
  local root
  local probe="$p"
  root="$(pwd -P)"
  # Refuse any symlinked component (leaf or ancestors, including dangling).
  while [ "$probe" != "/" ] && [ "$probe" != "." ]; do
    if [ -L "$probe" ]; then
      fail "Refusing to write through a symlink: $p"; exit 1
    fi
    [ -e "$probe" ] && break
    probe="$(dirname "$probe")"
  done
  # Physical destination must stay under the physical project root.
  local resolved
  resolved="$(cd "$(dirname "$probe")" 2>/dev/null && pwd -P)/$(basename "$probe")"
  case "$resolved" in
    "$root"/*) ;;
    *) fail "Refusing to write outside the project root: $p"; exit 1 ;;
  esac
}

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
        assert_inside_project "$dst"
    cp "$mdir/$src" "$dst"
        case "$src" in *.sh) chmod +x "$dst" ;; esac
        ;;
      copy-if-missing)
        if [ ! -f "$dst" ]; then
          mkdir -p "$(dirname "$dst")"
          assert_inside_project "$dst"
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

strip_module() {  # strip_module <module-name> — uninstall the files a module injected
  local m="$1"
  local mf="$TEMPLATES_DIR/modules/$m/manifest.json"
  if [ ! -f "$mf" ]; then
    warn "Cannot uninstall module '$m': its manifest is missing in this harness version — remove its files manually."
    return
  fi
  local line dst mode
  while IFS= read -r line; do
    if [ -z "$line" ]; then continue; fi
    mode=$(printf '%s\n' "$line" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if printf '%s\n' "$line" | grep -q '"dst"[[:space:]]*:[[:space:]]*{'; then
      dst=$(printf '%s\n' "$line" | sed -n "s/.*\"$TOOL\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")
    else
      dst=$(printf '%s\n' "$line" | sed -n 's/.*"dst"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    fi
    [ -z "$dst" ] && continue
    case "$mode" in
      copy|copy-if-missing)
        if [ -f "$dst" ]; then
          rm -f "$dst"
          ok "Removed $dst (module: $m)"
        fi
        ;;
      append-section)
        if [ -f "$dst" ] && grep -qF "<!-- harness:module:$m:start -->" "$dst"; then
          awk -v start="<!-- harness:module:$m:start -->" -v end="<!-- harness:module:$m:end -->" '
            index($0, start) { inblk = 1 }
            inblk && index($0, end) { inblk = 0; next }
            !inblk { print }
          ' "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"
          ok "Stripped module section from $dst (module: $m)"
        fi
        ;;
    esac
  done < <(manifest_injects "$mf")
}

generate_conventions() {  # generate_conventions <stack> > stdout — frame + language chunks
  local stack="$1"
  awk -v tpl="$TEMPLATES_DIR/docs/conventions.md.tpl" -v conv="$TEMPLATES_DIR/conventions/$stack.md" '
    function chunk(tag,   f, line, out) {
      out = ""
      while ((getline line < conv) > 0) {
        if (line == "<!-- " tag " -->") { f = 1; continue }
        if (line == "<!-- /" tag " -->") { f = 0 }
        if (f) out = out line "\n"
      }
      close(conv)
      return out
    }
    BEGIN {
      while ((getline line < tpl) > 0) {
        if      (line == "{{STYLE_RULES}}")     printf "%s", chunk("style")
        else if (line == "{{NAMING_RULES}}")    printf "%s", chunk("naming")
        else if (line == "{{FILE_STRUCTURE}}")  printf "%s", chunk("structure")
        else if (line == "{{TEST_RULES}}")      printf "%s", chunk("tests")
        else if (line == "{{ERROR_HANDLING}}")  printf "%s", chunk("errors")
        else if (line == "{{QUALITY_SECTION}}") printf "%s", chunk("quality")
        else print line
      }
      close(tpl)
    }
  '
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
  if grep -q '"harness_version"[[:space:]]*:' "$fl"; then
    sed "s|\"harness_version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"harness_version\": \"$HARNESS_VERSION\"|" "$fl" > "$fl.tmp" && mv "$fl.tmp" "$fl"
  else
    # Pre-versioning install: add the stamp as the last project property.
    sed "s|\"audit_level\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\"|\"audit_level\": \"\1\",\n    \"harness_version\": \"$HARNESS_VERSION\"|" "$fl" > "$fl.tmp" && mv "$fl.tmp" "$fl"
  fi
}

# ── Copy templates ─────────────────────────────────────
info "Installing harness templates..."

# docs/ stays at the project root
mkdir -p docs
cp "$TEMPLATES_DIR/docs/specs.md" ./docs/specs.md
cp "$TEMPLATES_DIR/docs/verification.md" ./docs/verification.md

# ── Conventions & architecture docs (stack- and architecture-aware) ──
ARCH_STORED=""
if [ -f "harness/feature_list.json" ]; then
  ARCH_STORED="$(sed -n 's/.*"architecture"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' harness/feature_list.json 2>/dev/null | head -n 1)"
fi
ARCH_NAME="${ARCH_FLAG:-$ARCH_STORED}"

CONV_TMP="$(mktemp)"
generate_conventions "$STACK" > "$CONV_TMP"
if [ -n "$ARCH_NAME" ] && [ -f "$TEMPLATES_DIR/architectures/$ARCH_NAME/conventions-section.md" ]; then
  { echo "<!-- harness:module:architecture:start -->"
    cat "$TEMPLATES_DIR/architectures/$ARCH_NAME/conventions-section.md"
    echo ""
    echo "<!-- harness:module:architecture:end -->"
  } >> "$CONV_TMP"
fi

if [ ! -f "docs/conventions.md" ]; then
  mv "$CONV_TMP" docs/conventions.md
  ok "Conventions generated (stack: $STACK${ARCH_NAME:+, architecture: $ARCH_NAME})"
elif [ -n "$ARCH_FLAG" ] && cmp -s "$CONV_TMP" docs/conventions.md; then
  mv "$CONV_TMP" docs/conventions.md
  ok "Conventions regenerated (stack: $STACK, architecture: $ARCH_NAME)"
elif [ -n "$ARCH_FLAG" ]; then
  # Explicit architecture choice: keep user content, refresh only the marked section.
  rm -f "$CONV_TMP"
  inject_append_section "docs/conventions.md" "architecture" \
    "$TEMPLATES_DIR/architectures/$ARCH_NAME/conventions-section.md"
  ok "Architecture conventions injected into docs/conventions.md ($ARCH_NAME)"
elif [ "$FORCE" -eq 1 ] && { cmp -s "$CONV_TMP" docs/conventions.md || \
  grep -q "Define coding style rules here." docs/conventions.md; }; then
  # Installer-generated content (or untouched placeholder defaults) self-heals.
  mv "$CONV_TMP" docs/conventions.md
  ok "Conventions refreshed (was installer-generated)"
else
  rm -f "$CONV_TMP"
  info "docs/conventions.md is customized — left untouched (pass --architecture=<name> to regenerate)"
fi

if [ -n "$ARCH_NAME" ]; then
  if [ ! -f "docs/architecture.md" ] || [ -n "$ARCH_FLAG" ] || \
     cmp -s "$TEMPLATES_DIR/architectures/$ARCH_NAME/architecture.md" docs/architecture.md || \
     grep -q "Define the architectural principles for this project here." docs/architecture.md; then
    cp "$TEMPLATES_DIR/architectures/$ARCH_NAME/architecture.md" docs/architecture.md
    ok "Architecture doc installed: $ARCH_NAME"
  else
    info "docs/architecture.md is customized — left untouched"
  fi
elif [ ! -f "docs/architecture.md" ]; then
  sed -e "s|{{ARCHITECTURE_PRINCIPLES}}|Define the architectural principles for this project here.|g" \
      -e "s|{{DATA_FLOW}}|Describe the data flow here.|g" \
      -e "s|{{ARCHITECTURE_DONT}}|List what NOT to do here.|g" \
      "$TEMPLATES_DIR/docs/architecture.md.tpl" > docs/architecture.md
fi

# Everything else groups under harness/
mkdir -p harness/progress harness/specs harness/logs
mkdir -p harness/tools
cp "$TEMPLATES_DIR/tools/validate-feature-list.py" ./harness/tools/
chmod +x ./harness/tools/validate-feature-list.py
cp "$TEMPLATES_DIR/tools/check-traceability.py" ./harness/tools/
chmod +x ./harness/tools/check-traceability.py
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
      -e "s|{{HARNESS_VERSION}}|$HARNESS_VERSION|g" \
      -e "s|{{ARCHITECTURE}}|${ARCH_NAME:-}|g" \
      "$TEMPLATES_DIR/feature_list.json" > harness/feature_list.json
else
  ok "Keeping existing harness/feature_list.json"
  refresh_project_metadata "harness/feature_list.json"
fi

if [ -n "$ARCH_NAME" ]; then
  if grep -q '"architecture"[[:space:]]*:' harness/feature_list.json; then
    sed "s|\"architecture\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"architecture\": \"$ARCH_NAME\"|" \
      harness/feature_list.json > harness/feature_list.json.tmp && mv harness/feature_list.json.tmp harness/feature_list.json
  elif grep -q '"harness_version"[[:space:]]*:' harness/feature_list.json; then
    sed "s|\"harness_version\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\"|\"harness_version\": \"\1\",\n    \"architecture\": \"$ARCH_NAME\"|" \
      harness/feature_list.json > harness/feature_list.json.tmp && mv harness/feature_list.json.tmp harness/feature_list.json
  fi
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

# ── Uninstall removed modules (--update --remove-modules) ──
if [ "${#REMOVED_MODULES[@]}" -gt 0 ]; then
  info "Removing modules: ${REMOVED_MODULES[*]}"
  for _m in "${REMOVED_MODULES[@]}"; do
    strip_module "$_m"
  done
fi

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
# No audit module left → the C7 audit checkpoint goes too.
if ! printf '%s\n' "${MODULES_SELECTED[*]:-}" | grep -qE 'security-audit|performance-benchmarks'; then
  if [ -f "harness/CHECKPOINTS.md" ] && grep -qF "<!-- harness:module:audit-checkpoint:start -->" harness/CHECKPOINTS.md; then
    awk -v start="<!-- harness:module:audit-checkpoint:start -->" -v end="<!-- harness:module:audit-checkpoint:end -->" '
      index($0, start) { inblk = 1 }
      inblk && index($0, end) { inblk = 0; next }
      !inblk { print }
    ' harness/CHECKPOINTS.md > harness/CHECKPOINTS.md.tmp && mv harness/CHECKPOINTS.md.tmp harness/CHECKPOINTS.md
    ok "Removed audit checkpoint (no audit module installed)"
  fi
fi
if [ "$AUDIT_LEVEL" != "basic" ]; then
  info "Audit level: $AUDIT_LEVEL"
fi

# ── Wekan credentials gitignore ─────────────────────────
if [ -f "harness/wekan.json" ]; then
  CRED_FILE="$(sed -n 's/^[[:space:]]*"credentials_file"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' harness/wekan.json)"
  if [ -n "$CRED_FILE" ] && { [ ! -f .gitignore ] || ! grep -qxF "$CRED_FILE" .gitignore; }; then
    printf '\n# Wekan API credentials (wekan-tickets) — never commit\n%s\n' "$CRED_FILE" >> .gitignore
    info "Gitignored $CRED_FILE (Wekan credentials)"
  fi
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
if command -v python3 >/dev/null 2>&1; then
  if python3 ./harness/tools/validate-feature-list.py ./harness/feature_list.json > /dev/null 2>&1; then
    ok "feature_list.json is valid (protocol v1)"
  else
    warn "feature_list.json does not satisfy protocol v1 — run: python3 harness/tools/validate-feature-list.py harness/feature_list.json"
  fi
fi
check_file "harness/init.sh"
check_file "harness/progress/current.md"
check_file "harness/progress/history.md"
check_file "docs/architecture.md"
check_file "docs/conventions.md"
check_file "docs/specs.md"
check_file "docs/verification.md"
check_dir "harness/specs"
check_dir "harness/logs"

for m in "${MODULES_SELECTED[@]:+${MODULES_SELECTED[@]}}"; do
  while IFS= read -r vpath; do
    if [ -z "$vpath" ]; then continue; fi
    check_file "$vpath"
  done < <(manifest_list "$TEMPLATES_DIR/modules/$m/manifest.json" "verify")
done

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  ok "Harness installed successfully for stack: $STACK (tool: $TOOL)"

  if [ "$TOOL" = "claude" ]; then
    ENTRY_FILE="CLAUDE.md"
    ROLES_DIR=".claude/agents/"
  else
    ENTRY_FILE="AGENTS.md"
    ROLES_DIR=".opencode/agent/"
  fi

  cat > HARNESS.md <<EOF
# Harness — $PROJECT_NAME

Installed with [harness-standard](https://github.com/jordimarsal/harness-standard) (\`$TOOL\`, \`$HARNESS_VERSION\`).

- **Stack detected:** $STACK
- **Architecture:** ${ARCH_NAME:-generic template}
- **Roles:** Leader · Spec Author · Implementer · Reviewer (\`$ROLES_DIR\`)
- **Gates:** \`harness/CHECKPOINTS.md\` · \`docs/verification.md\`
- **Process:** \`docs/specs.md\` — Spec-Driven Development with a human approval gate

## Next

1. Edit \`docs/architecture.md\` and \`docs/conventions.md\` for this project.
2. Add features to \`harness/feature_list.json\`.
3. Start the leader: \`$TOOL\`
4. Update later: re-run install.sh with \`--update\` (keeps specs, progress and settings).

First prompt:

> Read $ENTRY_FILE and start the leader workflow. Pick the first pending feature.
EOF

  # Badge suggestion — README.md is user-owned: suggest, never write.
  if [ -f README.md ] && ! grep -q "built with harness-standard" README.md; then
    echo ""
    echo "Tip: consider adding the badge to README.md (variants: harness-standard README, Badge section):"
    echo '  [![built with harness-standard](https://raw.githubusercontent.com/jordimarsal/harness-standard/main/assets/badge.svg)](https://github.com/jordimarsal/harness-standard)'
  fi

  echo ""
  echo "Next: $TOOL — open $TOOL, then prompt: Read $ENTRY_FILE and start the leader workflow."
else
  fail "Harness installation incomplete. Resolve errors above."
fi

exit $EXIT_CODE
