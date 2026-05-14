#!/usr/bin/env bash
# init.sh — Install the standardized harness into a project
#
# Usage: cd /path/to/your/project && /path/to/harness-standard/init.sh
#
# Detects tech stack, copies templates, adapts configuration.
# Safe: refuses to overwrite an existing harness.

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

# ── Check existing harness ─────────────────────────────
if [ -f "AGENTS.md" ] || [ -f "CHECKPOINTS.md" ]; then
  fail "A harness is already installed in this directory (AGENTS.md or CHECKPOINTS.md exists)."
  fail "Remove existing harness files before reinstalling."
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
    TEST_CMD="python3 -m unittest discover -s tests -q"
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

# ── Copy templates ─────────────────────────────────────
info "Installing harness templates..."

# Shared files
cp "$TEMPLATES_DIR/AGENTS.md" ./AGENTS.md
cp "$TEMPLATES_DIR/CHECKPOINTS.md" ./CHECKPOINTS.md

# .claude directory
mkdir -p .claude/agents
for agent in leader spec-author implementer reviewer; do
  cp "$TEMPLATES_DIR/.claude/agents/${agent}.md" ".claude/agents/${agent}.md"
done

# Settings with variable substitution
mkdir -p .claude
sed -e "s|{{TEST_CMD}}|$TEST_CMD|g" \
    -e "s|{{BUILD_CMD}}|$BUILD_CMD|g" \
    "$TEMPLATES_DIR/.claude/settings.json" > .claude/settings.json

# Progress
mkdir -p progress
cp "$TEMPLATES_DIR/progress/current.md" ./progress/current.md
cp "$TEMPLATES_DIR/progress/history.md" ./progress/history.md

# Specs
mkdir -p specs

# Docs
mkdir -p docs
cp "$TEMPLATES_DIR/docs/specs.md" ./docs/specs.md
cp "$TEMPLATES_DIR/docs/verification.md" ./docs/verification.md

# Architecture and conventions templates (user must fill)
sed -e "s|{{ARCHITECTURE_PRINCIPLES}}|Define the architectural principles for this project here.|g" \
    -e "s|{{DATA_FLOW}}|Describe the data flow here.|g" \
    -e "s|{{ARCHITECTURE_DONT}}|List what NOT to do here.|g" \
    "$TEMPLATES_DIR/docs/architecture.md.tpl" > docs/architecture.md

sed -e "s|{{STYLE_RULES}}|Define coding style rules here.|g" \
    -e "s|{{NAMING_RULES}}|Define naming conventions here.|g" \
    -e "s|{{FILE_STRUCTURE}}|Define file structure rules here.|g" \
    -e "s|{{TEST_RULES}}|Define testing rules here.|g" \
    -e "s|{{ERROR_HANDLING}}|Define error handling rules here.|g" \
    "$TEMPLATES_DIR/docs/conventions.md.tpl" > docs/conventions.md

# Stack-specific CLAUDE.md
if [ -f "$TEMPLATES_DIR/stacks/$STACK/CLAUDE.md.tpl" ]; then
  cp "$TEMPLATES_DIR/stacks/$STACK/CLAUDE.md.tpl" ./CLAUDE.md
else
  cp "$TEMPLATES_DIR/stacks/generic/CLAUDE.md.tpl" ./CLAUDE.md
fi

# Feature list
if [ ! -f "feature_list.json" ]; then
  sed "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
      "$TEMPLATES_DIR/feature_list.json" > feature_list.json
  ok "Created feature_list.json"
else
  warn "feature_list.json already exists — keeping existing file"
fi

# Copy project-level verification script
cp "$SCRIPT_DIR/init-verify.sh" ./init.sh
chmod +x ./init.sh

ok "Templates installed"

# ── Validation ─────────────────────────────────────────
echo ""
echo "── Validation ──────────────────────────────────────────"

EXIT_CODE=0

for f in CLAUDE.md AGENTS.md CHECKPOINTS.md feature_list.json progress/current.md progress/history.md docs/architecture.md docs/conventions.md docs/specs.md docs/verification.md .claude/settings.json init.sh; do
  if [ ! -f "$f" ]; then
    fail "Missing file: $f"
    EXIT_CODE=1
  else
    ok "Exists $f"
  fi
done

for a in leader spec-author implementer reviewer; do
  if [ ! -f ".claude/agents/${a}.md" ]; then
    fail "Missing agent: .claude/agents/${a}.md"
    EXIT_CODE=1
  else
    ok "Exists .claude/agents/${a}.md"
  fi
done

if [ ! -d "specs" ]; then
  fail "Missing directory: specs/"
  EXIT_CODE=1
else
  ok "Exists specs/"
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  ok "Harness installed successfully for stack: $STACK"
  echo ""
  info "Next steps:"
  info "  1. Edit docs/architecture.md with your project's architecture."
  info "  2. Edit docs/conventions.md with your project's coding conventions."
  info "  3. Add features to feature_list.json."
  info "  4. Start Claude Code and let the leader agent guide you."
else
  fail "Harness installation incomplete. Resolve errors above."
fi

exit $EXIT_CODE
