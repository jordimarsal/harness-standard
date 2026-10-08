#!/usr/bin/env bash
# tests/test-traceability.sh — Guards de check-traceability.py (no PASS buit)
#
# Usage: ./tests/test-traceability.sh
# Verifica que el tool (a) rebutja un root que no és directori, (b) rebutja una
# --feature sense requirements.md, (c) rebutja una feature amb 0 requisits,
# (d) passa el cas feliç amb línies per feature, i (e) que els templates
# workflow documenten la crida correcta i la regla d'assercions relatives.

set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$REPO_DIR/templates/tools/check-traceability.py"

PASS=0
FAIL=0
FAILED_NAMES=()
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

ok() {  # ok <nom>
  PASS=$((PASS + 1)); echo "    ok: $1"
}
ko() {  # ko <nom> <detall>
  FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1")
  echo "    FAIL: $1 — $2"
}

# ── (a) root que no és directori (la crida documentada antigament) ──────────
out=$(python3 "$TOOL" --feature demo "$REPO_DIR/package.json" 2>&1)
code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -q "root is not a directory"; then
  ok "root no-directori -> exit 2 amb pista"
else
  ko "root no-directori" "exit=$code out=$out"
fi

# ── (b) --feature desconeguda (sense requirements.md) ───────────────────────
mkdir -p "$TMP_ROOT/buit"
out=$(python3 "$TOOL" --feature no_existeix "$TMP_ROOT/buit" 2>&1)
code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -q "unknown feature"; then
  ok "--feature desconeguda -> exit 2"
else
  ko "--feature desconeguda" "exit=$code out=$out"
fi

# ── (c) feature amb 0 requisits parsejats ───────────────────────────────────
mkdir -p "$TMP_ROOT/zero/harness/specs/fantasma"
printf 'no hi ha cap R<num> aqui\n' > "$TMP_ROOT/zero/harness/specs/fantasma/requirements.md"
out=$(python3 "$TOOL" --feature fantasma "$TMP_ROOT/zero" 2>&1)
code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -q "no requirements parsed"; then
  ok "0 requisits -> exit 2"
else
  ko "0 requisits" "exit=$code out=$out"
fi

# ── (d) cas feliç amb fixture mínim -> exit 0 amb línies per feature ────────
PROJ="$TMP_ROOT/proj"
mkdir -p "$PROJ/harness/specs/demo" "$PROJ/harness/progress" "$PROJ/tests"
printf '## R1\nThe system shall parse fixtures.\n' > "$PROJ/harness/specs/demo/requirements.md"
cat > "$PROJ/harness/progress/impl_demo.md" << 'IMPL'
feature: demo

| Requirement | Test(s) | Implementation file(s) | Status |
|-------------|---------|------------------------|--------|
| R1          | R1      | x.py                   | done   |
IMPL
printf "test('R1 fixture', () => {});\n" > "$PROJ/tests/test_demo.js"
printf '{"features": [{"name": "demo", "status": "done"}]}' > "$PROJ/harness/feature_list.json"
out=$(python3 "$TOOL" --feature demo "$PROJ" 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "## demo: 1/1 requirements covered"; then
  ok "cas feliç -> exit 0 amb ## demo: 1/1"
else
  ko "cas feliç" "exit=$code out=$out"
fi

# ── (e) templates workflow: crida correcta + regla d'assercions relatives ───
for mode in claude opencode; do
  WF="$REPO_DIR/templates/workflow/$mode/hybrid.md"
  if grep -q "check-traceability.py --feature" "$WF" && \
     ! grep -q "check-traceability.py harness/feature_list.json" "$WF"; then
    ok "workflow/$mode: crida correcta (--feature, sense positional)"
  else
    ko "workflow/$mode" "crida vella o absent"
  fi
  if grep -q "vacuous" "$WF"; then
    ok "workflow/$mode: advertència de PASS buit"
  else
    ko "workflow/$mode" "falta l'advertència de PASS buit"
  fi
  if grep -qi "indexOf" "$WF"; then
    ok "workflow/$mode: regla d'assercions relatives"
  else
    ko "workflow/$mode" "falta la regla d'assercions relatives"
  fi
done

# ── Resum ───────────────────────────────────────────────────────────────────
echo ""
echo "test-traceability: $PASS pass, $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
  printf '    failed: %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
