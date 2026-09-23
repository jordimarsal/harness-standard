#!/usr/bin/env bash
# install.sh — remote bootstrap for Harness Standard.
#
# Usage:
#   curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=claude
#   bash install.sh [--tool=claude|opencode] [--dest DIR] [--ref REF] [--force]
#                   [--modules=m1,m2] [--audit-level=basic|standard|strict]
#
# Env: HARNESS_REPO_URL (default https://github.com/jordimarsal/harness-standard.git)
#      HARNESS_REF      (default v0.1.0)
set -euo pipefail

REPO_URL="${HARNESS_REPO_URL:-https://github.com/jordimarsal/harness-standard.git}"
REF="${HARNESS_REF:-v0.1.0}"
DEST="."
TOOL=""
PASSTHRU=()

while [ $# -gt 0 ]; do
  case "$1" in
    --tool=*)        TOOL="${1#*=}" ;;
    --tool)          shift; TOOL="${1:-}" ;;
    --dest=*)        DEST="${1#*=}" ;;
    --dest)          shift; DEST="${1:-}" ;;
    --ref=*)         REF="${1#*=}" ;;
    --ref)           shift; REF="${1:-}" ;;
    --force)         PASSTHRU+=(--force) ;;
    --modules=*|--audit-level=*) PASSTHRU+=("$1") ;;
    -h|--help)
      echo "Usage: install.sh [--tool=claude|opencode] [--dest DIR] [--ref REF] [--force] [--modules=...] [--audit-level=...]"
      exit 0 ;;
    *) echo "install.sh: unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

case "$TOOL" in
  ""|claude|opencode) ;;
  *) echo "install.sh: --tool must be claude or opencode" >&2; exit 1 ;;
esac

command -v git >/dev/null 2>&1 || { echo "install.sh: git is required" >&2; exit 1; }

mkdir -p "$DEST"
DEST_ABS="$(cd "$DEST" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching harness-standard ($REF)..."
if ! git clone --depth 1 --branch "$REF" --quiet "$REPO_URL" "$TMP/harness-standard" 2>/dev/null; then
  git clone --depth 1 --quiet "$REPO_URL" "$TMP/harness-standard"
fi

ARGS=()
[ -n "$TOOL" ] && ARGS+=(--tool="$TOOL")
ARGS+=("${PASSTHRU[@]+"${PASSTHRU[@]}"}")

( cd "$DEST_ABS" && bash "$TMP/harness-standard/init.sh" "${ARGS[@]+"${ARGS[@]}"}" )
