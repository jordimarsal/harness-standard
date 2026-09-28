#!/usr/bin/env bash
# tests/test-security.sh — Security remediation regression tests
set -u
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$REPO_DIR/init.sh"
PASS=0; FAIL=0; FAILED_NAMES=()
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

echo "=== Security remediation regression tests ==="

# 1. Gate fail-closed without tests
t="gate fail-closed without tests"
d="$TMP_ROOT/gate-fc"; mkdir -p "$d"
(cd "$d" && "$INIT" --tool=claude >/dev/null 2>&1)
if (cd "$d" && ./harness/init.sh >/dev/null 2>&1); then
  FAIL=$((FAIL + 1)); echo "FAIL: $t — gate attested green without tests"
else
  PASS=$((PASS + 1))
fi

# 2. done requires APPROVAL (validator called from project root)
t="done requires APPROVAL"
d="$TMP_ROOT/appr"; mkdir -p "$d"
(cd "$d" && "$INIT" --tool=claude >/dev/null 2>&1)
mkdir -p "$d/harness/specs/demo"
for f in requirements.md design.md tasks.md; do echo "# demo" > "$d/harness/specs/demo/$f"; done
cat > "$d/harness/feature_list.json" <<'J'
{"project": {"name": "test", "parallel": false, "modules": [], "audit_level": "basic"}, "features": [{"id": 1, "name": "demo", "title": "D", "description": "D", "acceptance": ["A"], "status": "done"}]}
J
if (cd "$d" && python3 harness/tools/validate-feature-list.py harness/feature_list.json >/dev/null 2>&1); then
  FAIL=$((FAIL + 1)); echo "FAIL: $t — done accepted without APPROVAL"
else
  PASS=$((PASS + 1))
fi
touch "$d/harness/specs/demo/APPROVAL"
if (cd "$d" && python3 harness/tools/validate-feature-list.py harness/feature_list.json >/dev/null 2>&1); then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1)); echo "FAIL: $t — done rejected despite APPROVAL"
fi

# 3. Ref-pin fail-closed
t="ref-pin fail-closed"
d="$TMP_ROOT/refpin"
if HARNESS_REPO_URL="$REPO_DIR" HARNESS_REF=v99.99.99-nonexistent \
     bash "$REPO_DIR/install.sh" --tool=claude --dest "$d" >/dev/null 2>&1; then
  FAIL=$((FAIL + 1)); echo "FAIL: $t — ref-pin silently fell back"
else
  PASS=$((PASS + 1))
fi

# 4. No curl -k in shipped SKILL.md
t="no curl -k in SKILL.md"
if grep -q "curl -sk" "$REPO_DIR/templates/modules/wekan-tickets/SKILL.md" 2>/dev/null; then
  FAIL=$((FAIL + 1)); echo "FAIL: $t — curl -sk still present"
else
  PASS=$((PASS + 1))
fi

# 5. Wekan credentials gitignored by installer
t="wekan credentials gitignored"
d="$TMP_ROOT/gitig"; mkdir -p "$d"
(cd "$d" && "$INIT" --tool=claude --modules=wekan-tickets >/dev/null 2>&1)
if [ -f "$d/.gitignore" ] && grep -q "wekan" "$d/.gitignore"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1)); echo "FAIL: $t — .gitignore entry missing (init.sh: wekan gitignore block)"
fi

# 6. Stop hook uses mktemp
t="Stop hook mktemp"
if grep -q "/tmp/harness_init.log" "$REPO_DIR/templates/.claude/settings.json" 2>/dev/null; then
  FAIL=$((FAIL + 1)); echo "FAIL: $t — fixed /tmp path still present"
else
  PASS=$((PASS + 1))
fi
if grep -q "mktemp" "$REPO_DIR/templates/.claude/settings.json" 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1)); echo "FAIL: $t — mktemp missing"
fi

# 7. npx --no-install in gate and hook
t="npx --no-install"
if grep -q "npx --no-install" "$REPO_DIR/init.sh" 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1)); echo "FAIL: $t — missing from init.sh"
fi
if grep -q "npx --no-install" "$REPO_DIR/init-verify.sh" 2>/dev/null; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1)); echo "FAIL: $t — missing from init-verify.sh"
fi

# 8. Sed injection blocked
t="sed injection blocked"
d="$TMP_ROOT/sed-inj"
mkdir -p "$d/x|touch PWNED_SEC_42 #"
cd "$d/x|touch PWNED_SEC_42 #"
touch requirements.txt
bash "$REPO_DIR/init.sh" --tool=claude </dev/null >/dev/null 2>&1
if [ -f PWNED_SEC_42 ]; then
  FAIL=$((FAIL + 1)); echo "FAIL: $t — sed injection succeeded"
else
  PASS=$((PASS + 1))
fi
cd "$TMP_ROOT"

# 9. Force teardown preserves non-harness files
t="force teardown preserves non-harness files"
d="$TMP_ROOT/teardown"; mkdir -p "$d"
(cd "$d" && "$INIT" --tool=claude >/dev/null 2>&1)
mkdir -p "$d/.claude/commands"
echo "my-command" > "$d/.claude/commands/custom.md"
(cd "$d" && "$INIT" --force --tool=claude >/dev/null 2>&1)
if [ -f "$d/.claude/commands/custom.md" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1)); echo "FAIL: $t — non-harness file destroyed"
fi

echo ""
echo "Security tests: PASS: $PASS  FAIL: $FAIL"
[ $FAIL -eq 0 ] || exit 1
exit 0
