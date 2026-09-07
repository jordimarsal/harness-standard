#!/usr/bin/env bash
# audit-security.sh — SAST + dependency scan for the security-audit module.
#
# Runs the stack-appropriate tools that are available and degrades to
# checklist-only when they are not (§6.3). The installer never runs this script;
# a non-zero exit means HIGH findings and the reviewer must reject approval.
#
# Usage: bash harness/tools/audit-security.sh [--stack=<stack>]
# Exit codes: 0 = no HIGH findings (or checklist-only), 1 = HIGH findings, 2 = usage error

set -uo pipefail

STACK=""
for arg in "$@"; do
  case "$arg" in
    --stack=*) STACK="${arg#--stack=}" ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$STACK" ]; then
  if [ -f "tsconfig.json" ]; then STACK="typescript"
  elif [ -f "package.json" ]; then STACK="node"
  elif [ -f "build.gradle" ] && { [ -f "AndroidManifest.xml" ] || [ -f "app/src/main/AndroidManifest.xml" ]; }; then STACK="android"
  elif [ -f "build.gradle" ] || [ -f "pom.xml" ]; then STACK="java"
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then STACK="python"
  elif [ -f "Cargo.toml" ]; then STACK="rust"
  else STACK="generic"
  fi
fi

REPORT="$(mktemp)"
trap 'rm -f "$REPORT"' EXIT
HIGH=0

echo "# Security Audit Report (stack: $STACK)"
echo ""

case "$STACK" in
  python)
    if command -v bandit >/dev/null 2>&1; then
      echo "## SAST: bandit"
      bandit -r . -x ./.venv,./venv,./node_modules -q > "$REPORT" 2>/dev/null || true
      grep -E "Issue:|Severity:|Location:" "$REPORT" || echo "No issues reported"
      if grep -q "Severity: High" "$REPORT"; then
        echo "HIGH severity finding(s) from bandit — see above"
        HIGH=1
      fi
    else
      echo "## SAST: bandit — SKIPPED (not installed; pip install bandit)"
    fi
    if command -v pip-audit >/dev/null 2>&1; then
      echo "## Dependency scan: pip-audit"
      if ! pip-audit --progress-spinner off > "$REPORT" 2>&1; then
        cat "$REPORT"
        HIGH=1
      else
        echo "No known vulnerabilities in resolved dependencies"
      fi
    else
      echo "## Dependency scan: pip-audit — SKIPPED (not installed; pip install pip-audit)"
    fi
    ;;
  typescript|node)
    if command -v npm >/dev/null 2>&1 && [ -f "package.json" ]; then
      echo "## Dependency scan: npm audit"
      if ! npm audit --audit-level=high > "$REPORT" 2>&1; then
        tail -n 30 "$REPORT"
        HIGH=1
      else
        echo "No high-severity dependency vulnerabilities"
      fi
    else
      echo "## Dependency scan: npm audit — SKIPPED (npm or package.json missing)"
    fi
    if ls .eslintrc* eslint.config.* >/dev/null 2>&1; then
      echo "## SAST: eslint — run 'npx eslint .' and review security rules"
    else
      echo "## SAST: eslint — SKIPPED (not configured)"
    fi
    ;;
  rust)
    if command -v cargo-audit >/dev/null 2>&1; then
      echo "## Dependency scan: cargo audit"
      if ! cargo audit > "$REPORT" 2>&1; then
        tail -n 30 "$REPORT"
        HIGH=1
      else
        echo "No vulnerable crates"
      fi
    else
      echo "## Dependency scan: cargo audit — SKIPPED (not installed; cargo install cargo-audit)"
    fi
    if cargo clippy --version >/dev/null 2>&1; then
      echo "## SAST: clippy — run 'cargo clippy -- -W clippy::all' and fix warnings"
    else
      echo "## SAST: clippy — SKIPPED"
    fi
    ;;
  java|android)
    if grep -q "dependency-check" build.gradle pom.xml 2>/dev/null; then
      echo "## Dependency scan: OWASP dependency-check is configured — run its Gradle/Maven task"
    else
      echo "## Dependency scan: OWASP dependency-check — not configured; checklist-only"
    fi
    ;;
  *)
    echo "## Checklist-only audit (no automated tools for stack: $STACK)"
    ;;
esac

echo ""
echo "## Checklist"
echo "Confirm every item of the Security Audit Checklist in docs/verification.md"
echo "(section 'Security Audit Checklist'). Record the outcome in the review file."
echo ""
if [ "$HIGH" -eq 1 ]; then
  echo "VERDICT: HIGH severity findings — approval must be rejected (audit_level standard/strict)."
  exit 1
fi
echo "VERDICT: no HIGH severity findings reported by automated tools."
exit 0
