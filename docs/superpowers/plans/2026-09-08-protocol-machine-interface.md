# Protocol & Machine Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn harness-standard into a machine-consumable system: a versioned file/tool protocol (v1), JSON output for the deterministic tools, a feature-list validator, a traceability checker, and frozen eval fixtures — the interface `harness-graph` (future LangGraph project) will consume.

**Architecture:** `docs/protocol.md` declares Protocol v1 (the contract); the three deterministic tools gain `--json` output conforming to it; two new stdlib-only core tools (`validate-feature-list.py`, `check-traceability.py`) are always installed into `harness/tools/`; `evals-fixtures/` freezes scenarios with expected outcomes.

**Tech Stack:** Bash + Python 3 stdlib only. No new runtime dependencies anywhere.

**Spec:** `docs/protocol.md` is BOTH the deliverable of Task 1 and the contract the rest of the plan implements. The approved design lives in this conversation (2026-09-08): protocol doc, --json modes, schema+validator, traceability checker, eval fixtures, reviewer conditional, README section.

## Global Constraints

- `init.sh` stays dependency-free (bash, coreutils, sed, grep, awk — no jq, no python3 at install time). Core tools are copied, never executed, by the installer. `validate-feature-list.py` may be *run* by the installer only behind `command -v python3`, warning-not-failing.
- New Python tools (`validate-feature-list.py`, `check-traceability.py`, `scan.py --json`): Python 3 stdlib only, no third-party imports.
- Existing human-readable output of every script is unchanged when `--json` is absent.
- Every JSON document starts with `"tool"` and `"protocol": 1` fields; booleans/verdicts exactly as specified in Task 1's contract table; no timestamps anywhere (deterministic output).
- Exit contracts: `audit-security.sh` 0/1/2, `bench.sh` 0/1 (comment fixed to match), `scan.py` 0/2, validators 0 valid / 1 invalid / 2 usage.
- All file content in English. Tests never make network calls.
- Baseline suite: 207 PASS / 0 FAIL at c959c8f. Every task ends with the full suite green. PASS counts in steps are exact (assertions counted); `FAIL: 0` is the binding outcome everywhere.
- Manifest format discipline unchanged. Templates copied verbatim — the reviewer template edit (Task 7) must be identical in both tool copies.

## File Structure

```
docs/protocol.md                                          # Task 1: Protocol v1 contract
templates/modules/security-audit/audit-security.sh        # Task 2: --json
templates/modules/performance-benchmarks/bench.sh         # Task 3: --json
templates/modules/project-scanner/scan.py                 # Task 4: --json
templates/feature_list.schema.json                        # Task 5: schema (doc contract)
templates/tools/validate-feature-list.py                  # Task 5: core tool (source)
templates/tools/check-traceability.py                     # Task 6: core tool (source)
init.sh                                                   # Tasks 5-6: install core tools + validation hook
templates/.claude/agents/reviewer.md                      # Task 7: conditional checker line
templates/.opencode/agent/reviewer.md                     # Task 7: conditional checker line
evals-fixtures/{README.md,01-*,02-*,03-*}                 # Task 7: frozen corpus
README.md                                                 # Task 7: machine-interface section
tests/test-install.sh                                     # every task after 1
```

---

### Task 1: Protocol v1 document

No code — the contract everything else implements and references.

**Files:**
- Create: `docs/protocol.md`

**Interfaces:**
- Produces: Protocol v1.0.0 — the exact JSON shapes Tasks 2-4 emit, the file contracts Tasks 5-6 validate, the invariant list C2 encodes.

- [ ] **Step 1: Write the document**

`docs/protocol.md`:

````markdown
# Harness Protocol v1

> This document is the machine-facing contract of harness-standard. It defines the
> files a harness install produces, the invariants they obey, and the JSON output of
> the deterministic tools. `harness-graph` (or any orchestrator) implements this
> protocol; harness-standard defines and documents it.
>
> **Version:** 1.0.0 (semver). Breaking changes bump the major version and update
> every `"protocol"` field in tool output.

## 1. State machine

Feature statuses in `feature_list.json`:

```
pending → spec_ready → in_progress → done
                  ▲         │
                  └──── blocked
```

- `spec_ready → in_progress` requires human approval (HITL gate).
- Invariant I1: at most one feature in `in_progress` at a time.

## 2. `harness/feature_list.json`

Full schema: `templates/feature_list.schema.json` (JSON Schema draft-07). Summary:

- `project`: `{name: string, parallel: bool, modules: string[], audit_level: "basic"|"standard"|"strict"}`
- `features[]`: `{id: int, name: snake_case, title, description, acceptance: string[], status: <state>, wekan_card?: string}`

Validation: `python3 harness/tools/validate-feature-list.py` (exit 0 valid, 1 invalid, `--json` for machine output).

## 3. Spec trio

Per feature `harness/specs/<name>/`:

- `requirements.md` — EARS notation; every criterion carries an `R<n>` identifier.
- `design.md` — files, signatures, `## Architectural Decisions` section.
- `tasks.md` — ordered tasks `T<n>`, each listing the `R<n>` it covers, optional `depends_on`.

## 4. Progress and traceability

- `harness/progress/current.md` — active session state.
- `harness/progress/impl_<session>.md` — per feature, MUST contain a traceability table:

  ```markdown
  | Requirement | Test(s)              | Implementation file(s) | Status |
  |-------------|----------------------|------------------------|--------|
  | R1          | test_orders_create   | src/core/orders.py     | done   |
  ```

  Test cell: comma/space-separated test identifiers; each identifier must appear
  literally (file or function name) under `tests/`.
- `harness/progress/review_<feature>.md` — reviewer verdict.

Validation: `python3 harness/tools/check-traceability.py --all` (exit 0 covered, 1 gaps, `--json` for machine output).

## 5. Tool JSON contracts

Every tool: `"tool"` + `"protocol": 1` first fields; no timestamps; same exit codes
as text mode. Human output is the default; `--json` switches.

### audit-security.sh --json

```json
{
  "tool": "audit-security",
  "protocol": 1,
  "stack": "python",
  "mode": "automated" | "checklist-only",
  "verdict": "PASS" | "REJECT",
  "findings": [
    {"severity": "HIGH" | "MEDIUM" | "LOW" | "UNKNOWN", "tool": "bandit", "rule": "B104", "file": "...", "message": "..."}
  ],
  "skipped": ["pip-audit: not installed"]
}
```

- `mode: "checklist-only"` when no automated tool ran for the stack.
- `verdict: "REJECT"` iff at least one HIGH finding (exit 1); else `PASS` (exit 0).
- `findings` are best-effort: populated from bandit/pip-audit (python stack) and npm
  audit (node stacks) when their JSON output and a runtime are available; otherwise
  `[]` with the reason in `skipped`.

### bench.sh --json

```json
{
  "tool": "bench",
  "protocol": 1,
  "stack": "python",
  "mode": "run" | "record-only" | "checklist-only",
  "results": [{"name": "test_x", "mean_ms": 42.3}],
  "regressions": ["test_x"],
  "verdict": "PASS" | "REJECT"
}
```

- `verdict: "REJECT"` iff `regressions` is non-empty (exit 1); else `PASS` (exit 0).

### scan.py --json

Same commands as text mode; output is a single JSON object per command:

- `--summary`: `{"tool": "scan", "protocol": 1, "command": "summary", "stack": "python" | "generic", "files": [...], "total_files": N, "test_files": N, "packages": N, "edges": N, "entry_points": [...], "missing_docstrings": N, "high_risk": [...], "duplicates": {"name": [paths]}}`
- `--impact F`: `{"tool": "scan", "protocol": 1, "command": "impact", "file": "...", "dependencies": [...], "dependents": [...], "tests_affected": [...], "impact_level": "HIGH" | "MEDIUM", "change_risk": "HIGH" | "MEDIUM" | "LOW"}`
- `--duplicates`: `{"tool": "scan", "protocol": 1, "command": "duplicates", "duplicates": {...}}`
- `--style N`: `{"tool": "scan", "protocol": 1, "command": "style", "sample": [{"path": "...", "classes": [...], "regions": [...], "first_imports": [...]}]}`

### validate-feature-list.py --json

```json
{"tool": "validate-feature-list", "protocol": 1, "valid": true | false, "errors": [{"path": "project.audit_level", "code": "invalid_enum", "message": "..."}]}
```

### check-traceability.py --json

```json
{
  "tool": "check-traceability",
  "protocol": 1,
  "verdict": "PASS" | "FAIL",
  "features": [
    {"name": "feat-a", "requirements": 3, "covered": 3, "gaps": [], "unresolved": []}
  ]
}
```

- `gaps`: requirements present in `requirements.md` but absent from every impl table,
  or whose test identifiers cannot be found under `tests/`.
- `unresolved`: table rows whose Status is not `done` (informational).

## 6. Module injection markers

Sections appended to shared files are wrapped in:

```
<!-- harness:module:<module-name>:start -->
<!-- harness:module:<module-name>:end -->
```

`--force` replaces only the content between a module's own markers.

## 7. Audit levels

- `basic` — manual checklist confirmation by the reviewer.
- `standard` — reviewer runs `harness/tools/audit-security.sh` (text or `--json`); HIGH rejects.
- `strict` — standard + `harness/tools/bench.sh`; critical regression rejects.
````

- [ ] **Step 2: Suite stays green**

Run: `bash tests/test-install.sh 2>&1 | tail -2`
Expected: `PASS: 207  FAIL: 0`

- [ ] **Step 3: Commit**

```bash
git add docs/protocol.md
git commit -m "docs: Harness Protocol v1 — file contracts and tool JSON shapes"
```

---

### Task 2: audit-security.sh --json

**Files:**
- Modify: `templates/modules/security-audit/audit-security.sh`
- Test: `tests/test-install.sh` (1 new test function)

**Interfaces:**
- Consumes: existing text-mode structure (stack detection, tool branches, HIGH counter).
- Produces: `--json` flag → Protocol v1 shape (Task 1 §5); unknown arg now exits 2 (makes the documented usage exit real again).

- [ ] **Step 1: Write the failing test**

Add after `test_modules_install_strict` in `tests/test-install.sh`:

```bash
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
```

Call in Main after `test_modules_install_strict`:

```bash
test_audit_json_output
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 2` — `--json` unknown-arg exit 2 kills the run (first fail) and audit.json never parses (second).

- [ ] **Step 3: Implement --json in audit-security.sh**

Changes to `templates/modules/security-audit/audit-security.sh`:

a) Argument parsing becomes:

```bash
JSON=0
STACK=""
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    --stack=*) STACK="${arg#--stack=}" ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done
```

b) The script currently runs tools and greps their text output. Restructure the body so the tool-running part is shared, with JSON-mode findings extraction. Replace the `case "$STACK" in` block with:

```bash
FINDINGS_JSON="[]"
MODE="automated"

json_escape() {  # json_escape <string> — quote for embedding in JSON
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '
}

extract_bandit_json() {  # <report-file-with-bandit-json> → findings array fragment
  python3 - "$1" <<'PYEOF' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("[]")
    raise SystemExit(0)
out = []
for r in d.get("results", []):
    out.append({
        "severity": r.get("issue_severity", "UNKNOWN"),
        "tool": "bandit",
        "rule": r.get("test_id", ""),
        "file": r.get("filename", ""),
        "message": (r.get("issue_text") or "")[:200],
    })
print(json.dumps(out))
PYEOF
}

extract_pip_audit_json() {  # <report-file-with-pip-audit-json>
  python3 - "$1" <<'PYEOF' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("[]")
    raise SystemExit(0)
out = []
for dep in d.get("dependencies", []):
    for v in dep.get("vulns", []):
        out.append({
            "severity": "UNKNOWN",
            "tool": "pip-audit",
            "rule": ",".join(v.get("fix_versions", []) or []) or (v.get("id") or ""),
            "file": f"{dep.get('name','')}=={dep.get('version','')}",
            "message": (v.get("description") or "")[:200],
        })
print(json.dumps(out))
PYEOF
}

extract_npm_audit_json() {  # <report-file-with-npm-audit-json>
  if [ ! -f "$1" ]; then echo "[]"; return; fi
  node -e '
const fs = require("fs");
let d;
try { d = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { console.log("[]"); process.exit(0); }
const out = [];
const vulns = (d.vulnerabilities && typeof d.vulnerabilities === "object") ? Object.values(d.vulnerabilities) : [];
for (const v of vulns) {
  out.push({severity: (v.severity || "unknown").toUpperCase(), tool: "npm-audit", rule: (v.via || []).map(x => typeof x === "string" ? x : (x.source || "")).join(","), file: v.name || "", message: ((v.title || "") + "").slice(0, 200)});
}
console.log(JSON.stringify(out));
' "$1" 2>/dev/null || echo "[]"
}
```

Then the per-stack branches: when `JSON=0` they behave EXACTLY as today (byte-identical text output); when `JSON=1` they run tools with native JSON output and extract findings. Full replacement for the `case "$STACK"` block:

```bash
case "$STACK" in
  python)
    if command -v bandit >/dev/null 2>&1; then
      if [ "$JSON" -eq 1 ]; then
        bandit -r . -x ./.venv,./venv,./node_modules -q -f json > "$REPORT" 2>/dev/null || true
        FINDINGS_JSON="$(extract_bandit_json "$REPORT")"
        if grep -q '"issue_severity": "HIGH"' "$REPORT"; then
          HIGH=1
        fi
      else
        bandit -r . -x ./.venv,./venv,./node_modules -q > "$REPORT" 2>/dev/null || true
        grep -E "Issue:|Severity:|Location:" "$REPORT" || echo "No issues reported"
        if grep -q "Severity: High" "$REPORT"; then
          echo "HIGH severity finding(s) from bandit — see above"
          HIGH=1
        fi
      fi
    else
      [ "$JSON" -eq 1 ] && SKIPPED+=("bandit: not installed")
      echo "## SAST: bandit — SKIPPED (not installed; pip install bandit)"
    fi
    if command -v pip-audit >/dev/null 2>&1; then
      if [ "$JSON" -eq 1 ]; then
        if ! pip-audit --progress-spinner off --format json > "$REPORT" 2>&1; then
          PA="$(extract_pip_audit_json "$REPORT")"
          FINDINGS_JSON="$(python3 -c "import json,sys; print(json.dumps(json.loads(sys.argv[1]) + json.loads(sys.argv[2])))" "$FINDINGS_JSON" "$PA" 2>/dev/null || echo "$FINDINGS_JSON")"
          HIGH=1
        fi
      else
        if ! pip-audit --progress-spinner off > "$REPORT" 2>&1; then
          cat "$REPORT"
          HIGH=1
        else
          echo "No known vulnerabilities in resolved dependencies"
        fi
      fi
    else
      [ "$JSON" -eq 1 ] && SKIPPED+=("pip-audit: not installed")
      echo "## Dependency scan: pip-audit — SKIPPED (not installed; pip install pip-audit)"
    fi
    ;;
  typescript|node)
    if command -v npm >/dev/null 2>&1 && [ -f "package.json" ]; then
      if [ "$JSON" -eq 1 ]; then
        if ! npm audit --audit-level=high --json > "$REPORT" 2>&1; then
          FINDINGS_JSON="$(extract_npm_audit_json "$REPORT")"
          HIGH=1
        fi
      else
        if ! npm audit --audit-level=high > "$REPORT" 2>&1; then
          tail -n 30 "$REPORT"
          HIGH=1
        else
          echo "No high-severity dependency vulnerabilities"
        fi
      fi
    else
      [ "$JSON" -eq 1 ] && SKIPPED+=("npm audit: npm or package.json missing")
      echo "## Dependency scan: npm audit — SKIPPED (npm or package.json missing)"
    fi
    if ls .eslintrc* eslint.config.* >/dev/null 2>&1; then
      echo "## SAST: eslint — run 'npx eslint .' and review security rules"
    else
      [ "$JSON" -eq 1 ] && SKIPPED+=("eslint: not configured")
      echo "## SAST: eslint — SKIPPED (not configured)"
    fi
    ;;
  rust)
    if command -v cargo-audit >/dev/null 2>&1; then
      if ! cargo audit > "$REPORT" 2>&1; then
        [ "$JSON" -eq 0 ] && tail -n 30 "$REPORT"
        HIGH=1
      fi
    else
      [ "$JSON" -eq 1 ] && SKIPPED+=("cargo-audit: not installed")
      echo "## Dependency scan: cargo audit — SKIPPED (not installed; cargo install cargo-audit)"
    fi
    if cargo clippy --version >/dev/null 2>&1; then
      echo "## SAST: clippy — run 'cargo clippy -- -W clippy::all' and fix warnings"
    else
      [ "$JSON" -eq 1 ] && SKIPPED+=("clippy: not installed")
      echo "## SAST: clippy — SKIPPED"
    fi
    ;;
  java|android)
    MODE="checklist-only"
    if grep -q "dependency-check" build.gradle pom.xml 2>/dev/null; then
      echo "## Dependency scan: OWASP dependency-check is configured — run its Gradle/Maven task"
    else
      [ "$JSON" -eq 1 ] && SKIPPED+=("dependency-check: not configured")
      echo "## Dependency scan: OWASP dependency-check — not configured; checklist-only"
    fi
    ;;
  *)
    MODE="checklist-only"
    [ "$JSON" -eq 1 ] || echo "## Checklist-only audit (no automated tools for stack: $STACK)"
    ;;
esac
```

Notes: the TEXT branches are the original lines verbatim (bandit without `-f json` grepping `Severity: High`); the JSON branches are new. `ls .eslintrc* eslint.config.*` keeps its `>/dev/null 2>&1` guard. `set -uo pipefail` (no `-e`): the `[ ... ] && cmd` short-circuits are safe.

c) Declaration of SKIPPED near the top (before the case): `SKIPPED=()`; and verdict/report tail becomes:

```bash
if [ "$JSON" -eq 1 ]; then
  MODE_DETECT=1
  VERDICT="PASS"
  [ "$HIGH" -eq 1 ] && VERDICT="REJECT"
  SKIPPED_JSON="[]"
  if [ "${#SKIPPED[@]}" -gt 0 ]; then
    SKIPPED_JSON="$(printf '"%s",' "$(for s in "${SKIPPED[@]}"; do json_escape "$s"; done)" | sed 's/,$//')"
    SKIPPED_JSON="[$SKIPPED_JSON]"
  fi
  printf '{"tool":"audit-security","protocol":1,"stack":"%s","mode":"%s","verdict":"%s","findings":%s,"skipped":%s}\n' \
    "$(json_escape "$STACK")" "$MODE" "$VERDICT" "$FINDINGS_JSON" "$SKIPPED_JSON"
else
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
fi
[ "$HIGH" -eq 1 ] && exit 1
exit 0
```

SKIPPED_JSON building is fiddly — simpler and safer:

```bash
SKIPPED_JSON="[]"
if [ "${#SKIPPED[@]}" -gt 0 ]; then
  SKIPPED_JSON="["
  first=1
  for s in "${SKIPPED[@]}"; do
    if [ $first -eq 1 ]; then first=0; else SKIPPED_JSON="$SKIPPED_JSON,"; fi
    SKIPPED_JSON="$SKIPPED_JSON\"$(json_escape "$s")\""
  done
  SKIPPED_JSON="$SKIPPED_JSON]"
fi
```

Use this loop version. Also `set -uo pipefail` interplay: `[ "$HIGH" -eq 1 ] && VERDICT=...` as last-command risk — the script has no `-e`, so `&&` short-circuits are safe.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -2`
Expected: `PASS: 212  FAIL: 0` (207 + 5 new assertions).

- [ ] **Step 5: Commit**

```bash
git add templates/modules/security-audit/audit-security.sh tests/test-install.sh
git commit -m "feat: audit-security.sh --json (protocol v1) and real usage exit 2"
```

---

### Task 3: bench.sh --json

**Files:**
- Modify: `templates/modules/performance-benchmarks/bench.sh`
- Test: `tests/test-install.sh` (1 new test function)

**Interfaces:**
- Consumes: existing run/compare structure (STACK detection, MEASURED, REJECT, `.bench-last.json`).
- Produces: `--json` → Protocol v1 shape (Task 1 §5).

- [ ] **Step 1: Write the failing test**

Add after `test_audit_json_output`:

```bash
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
```

(In the test env pytest-benchmark may or may not be installed — the assertion accepts both `run` and `record-only`; `results` is `[]` in record-only and the verdict PASS either way. This keeps the test deterministic without pinning the dev env.)

Call in Main after `test_audit_json_output`:

```bash
test_bench_json_output
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 1` — the current bench.sh takes no arguments, so `--json` is silently ignored: the run exits 0 but `bench.json` contains text mode output and fails the protocol-v1 shape check.

- [ ] **Step 3: Implement --json in bench.sh**

a) Argument parsing after the STACK detection block:

```bash
JSON=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done
```

b) Track results/regressions. In the python runner branch, after a successful measurement (`MEASURED=1`), add:

```bash
        RESULTS_JSON="$(python3 - <<'PYEOF' 2>/dev/null || echo "[]"
import json
try:
    d = json.load(open("harness/.bench-last.json"))
    print(json.dumps([{"name": b["name"], "mean_ms": round(b["stats"]["mean"] * 1000.0, 3)} for b in d.get("benchmarks", [])]))
except Exception:
    print("[]")
PYEOF
)"
```

c) The comparison block: additionally collect failing names. Inside the comparison heredoc python, print a machine line the script can capture. Simplest: change the comparison invocation to write regressions to a file:

```bash
if ! python3 - "$BASELINES" "harness/.bench-last.json" "$OUT.regres" <<'PYEOF'; then
import json, sys
base = json.load(open(sys.argv[1]))
data = json.load(open(sys.argv[2]))
regres = open(sys.argv[3], "w")
last = {b["name"]: b["stats"]["mean"] * 1000.0 for b in data["benchmarks"]}
reject = False
for name, entry in base.items():
    if name not in last:
        print(f"- {name}: no measurement found (baseline stale?)")
        continue
    mean_ms = last[name]
    ref = entry.get("mean_ms")
    th = entry.get("thresholds", {}).get("mean_ms", {})
    warn_m = th.get("warning", 1.5)
    crit_m = th.get("critical", 2.0)
    if ref is None:
        print(f"- {name}: measured {mean_ms:.1f} ms (no reference mean_ms yet; record it)")
        continue
    ratio = mean_ms / ref
    if ratio > crit_m:
        print(f"- {name}: REGRESSION {ratio:.2f}x vs baseline {ref:.1f} ms (critical {crit_m}x)")
        regres.write(name + "\n")
        reject = True
    elif ratio > warn_m:
        print(f"- {name}: WARNING {ratio:.2f}x vs baseline {ref:.1f} ms")
    else:
        print(f"- {name}: ok {mean_ms:.1f} ms ({ratio:.2f}x baseline)")
regres.close()
sys.exit(1 if reject else 0)
PYEOF
    REJECT=1
  fi
  REGRESSIONS="[]"
  if [ -f "$OUT.regres" ]; then
    REGRESSIONS="$(python3 -c "import json,sys; print(json.dumps([l.strip() for l in open(sys.argv[1]) if l.strip()]))" "$OUT.regres" 2>/dev/null || echo "[]")"
    rm -f "$OUT.regres"
  fi
```

(The heredoc body is identical to today's except for the extra argv and the `regres` writes. Text output unchanged.)

d) The comparison guard gains the JSON-independent `REGRESSIONS="[]"` default next to `MEASURED=0` / `REJECT=0` at the top.

e) Final section:

```bash
if [ "$JSON" -eq 1 ]; then
  MODE="checklist-only"
  [ "$STACK" = "python" ] || [ "$STACK" = "typescript" ] || [ "$STACK" = "node" ] || [ "$STACK" = "rust" ] && MODE="record-only"
  [ "$MEASURED" -eq 1 ] && MODE="run"
  VERDICT="PASS"
  [ "$REJECT" -eq 1 ] && VERDICT="REJECT"
  printf '{"tool":"bench","protocol":1,"stack":"%s","mode":"%s","results":%s,"regressions":%s,"verdict":"%s"}\n' \
    "$STACK" "$MODE" "${RESULTS_JSON:-[]}" "$REGRESSIONS" "$VERDICT"
else
  echo ""
  if [ "$REJECT" -eq 1 ]; then
    echo "VERDICT: benchmark regression beyond critical threshold — approval rejected (strict)."
    exit 1
  fi
  echo "VERDICT: no benchmark regression."
  exit 0
fi
[ "$REJECT" -eq 1 ] && exit 1
exit 0
```

Also fix the header comment: `# Exit codes: 0 = ok or record-only, 1 = regression beyond critical threshold` (drop the unreachable `2 = usage error` line — the new arg parsing DOES exit 2 on unknown args, so instead the comment becomes `0/1 as before; 2 = usage error` which is now true).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -2`
Expected: `PASS: 215  FAIL: 0` (212 + 3 new assertions: install, run, shape).

- [ ] **Step 5: Commit**

```bash
git add templates/modules/performance-benchmarks/bench.sh tests/test-install.sh
git commit -m "feat: bench.sh --json (protocol v1) with regression list"
```

---

### Task 4: scan.py --json

**Files:**
- Modify: `templates/modules/project-scanner/scan.py`
- Test: `tests/test-install.sh` (1 new test function)

**Interfaces:**
- Consumes: existing Scanner class and command functions (text output untouched).
- Produces: `--json` → one JSON object per command (Task 1 §5).

- [ ] **Step 1: Write the failing test**

Add after `test_bench_json_output`:

```bash
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
assert d["total_files"] == 2 and "core/models.py" in d["files"]
assert d["duplicates"] == {} and d["high_risk"] == []
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
```

Call in Main after `test_bench_json_output`:

```bash
test_scan_json_output
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 2` — `--json` hits the unknown-argument branch (exit 2) on both invocations.

- [ ] **Step 3: Implement --json in scan.py**

a) Add `import json` to the stdlib imports.

b) `main()` parsing gains `--json`:

```python
    as_json = False
    ...
        elif a == "--json":
            as_json = True
```

c) New JSON emitters (place next to the cmd_ functions). They reuse the same Scanner indexes:

```python
def json_summary(sc: Scanner) -> dict:
    files = sc.files
    test_files = [f for f in files if "test" in f.path.name or "test" in f.path.parent.name]
    entry_points = [f for f in files if f.entry_point]
    missing_docs = [f for f in files if f.classes and not f.docstring]
    high = [f for f in files if sc.risk(f) == "HIGH"]
    packages = sorted({str(f.path.parent) for f in files})
    return {
        "tool": "scan",
        "protocol": 1,
        "command": "summary",
        "stack": "python" if files else "generic",
        "files": sorted(str(f.path) for f in files),
        "total_files": len(files),
        "test_files": len(test_files),
        "packages": len(packages),
        "edges": sum(len(f.dependencies) for f in files),
        "entry_points": [str(f.path) for f in entry_points],
        "missing_docstrings": len(missing_docs),
        "high_risk": [str(f.path) for f in high],
        "duplicates": sc.find_duplicates(),
    }


def json_impact(sc: Scanner, target: str) -> dict:
    sf = _find_file(sc, target)
    if sf is None:
        return {"tool": "scan", "protocol": 1, "command": "impact", "error": f"file not found in project: {target}"}
    dependents = sorted(sc.affected_by(str(sf.path)))
    tests = [d for d in dependents if "test" in d]
    return {
        "tool": "scan",
        "protocol": 1,
        "command": "impact",
        "file": str(sf.path),
        "dependencies": sorted(sf.dependencies),
        "dependents": dependents,
        "tests_affected": tests,
        "impact_level": "HIGH" if dependents else "MEDIUM",
        "change_risk": sc.risk(sf),
    }
```

d) Refactor target lookup out of `cmd_impact` so both share it — replace the lookup portion of `cmd_impact` with a helper and use it from both:

```python
def _find_file(sc: Scanner, target: str) -> SourceFile | None:
    path = Path(target)
    sf = next((f for f in sc.files if f.path == path), None)
    if sf is None and path.is_absolute():
        try:
            rel = path.resolve().relative_to(sc.root.resolve())
        except ValueError:
            rel = None
        if rel is not None:
            sf = next((f for f in sc.files if f.path == rel), None)
    return sf
```

(e) In `main()`, dispatch: after scanning, if `as_json`:

```python
    if as_json:
        if command == "--summary":
            print(json.dumps(json_summary(sc)))
        elif command == "--impact":
            print(json.dumps(json_impact(sc, target or "")))
        elif command == "--duplicates":
            print(json.dumps({"tool": "scan", "protocol": 1, "command": "duplicates", "duplicates": sc.find_duplicates()}))
        elif command == "--style":
            print(json.dumps({"tool": "scan", "protocol": 1, "command": "style", "sample": [
                {"path": str(sf.path), "classes": sf.classes, "regions": sf.regions, "first_imports": sf.imports[:3]}
                for sf in [f for f in sc.files if "test" not in f.path.name][:style_n]
            ]}))
        return 0
```

Text mode is the existing code path, untouched. Empty project + `--json --summary` returns the same object with `stack: "generic"`, `files: []` (no separate fallback needed).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -2`
Expected: `PASS: 220  FAIL: 0` (215 + 5 new assertions).

- [ ] **Step 5: Commit**

```bash
git add templates/modules/project-scanner/scan.py tests/test-install.sh
git commit -m "feat: scan.py --json (protocol v1) for all commands"
```

---

### Task 5: feature_list schema + validator + installer core tools

**Files:**
- Create: `templates/feature_list.schema.json`
- Create: `templates/tools/validate-feature-list.py` (executable source)
- Modify: `init.sh` (always create `harness/tools/`, install validator, validation hook)
- Test: `tests/test-install.sh` (2 new test functions + 1 existing test updated)

**Interfaces:**
- Produces: `python3 harness/tools/validate-feature-list.py [--json] <feature-list>` — exit 0 valid / 1 invalid / 2 usage; JSON per Task 1 §5. Installer always installs it; Task 6 adds the second tool to the same mechanism.

- [ ] **Step 1: Write the failing tests**

a) UPDATE the existing `test_default_install_no_modules` — core tools now always exist. Replace its `assert_no_dir "$t" "$d/harness/tools"` line with:

```bash
  assert_file "$t" "$d/harness/tools/validate-feature-list.py"
  assert_no_file "$t" "$d/harness/tools/scan.py"
  assert_no_file "$t" "$d/harness/tools/audit-security.sh"
```

b) New test function:

```bash
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
```

Call in Main after `test_scan_json_output`:

```bash
test_feature_list_validator
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 2` — the updated default test misses the validator file (FAIL 1); the new test's first validator run fails with "No such file" and returns early (FAIL 1).

- [ ] **Step 3: Create the schema**

`templates/feature_list.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Harness feature list (protocol v1)",
  "type": "object",
  "required": ["project", "features"],
  "additionalProperties": false,
  "properties": {
    "project": {
      "type": "object",
      "required": ["name", "parallel", "modules", "audit_level"],
      "additionalProperties": true,
      "properties": {
        "name": {"type": "string", "minLength": 1},
        "parallel": {"type": "boolean"},
        "modules": {"type": "array", "items": {"type": "string"}},
        "audit_level": {"enum": ["basic", "standard", "strict"]}
      }
    },
    "features": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "name", "title", "description", "acceptance", "status"],
        "additionalProperties": true,
        "properties": {
          "id": {"type": "integer"},
          "name": {"type": "string", "pattern": "^[a-z0-9_]+$"},
          "title": {"type": "string"},
          "description": {"type": "string"},
          "acceptance": {"type": "array", "items": {"type": "string"}},
          "status": {"enum": ["pending", "spec_ready", "in_progress", "blocked", "done"]},
          "wekan_card": {"type": "string"}
        }
      }
    }
  }
}
```

- [ ] **Step 4: Create the validator**

`templates/tools/validate-feature-list.py` (chmod +x; stdlib only):

```python
#!/usr/bin/env python3
"""Validate a harness feature_list.json against Protocol v1 rules.

The JSON Schema (templates/feature_list.schema.json) is the documented
contract; this script enforces the same rules with the stdlib only — no
jsonschema dependency on installed projects.

Usage: validate-feature-list.py [--json] <feature-list.json>
Exit codes: 0 valid, 1 invalid, 2 usage error.
"""

from __future__ import annotations

import json
import re
import sys

STATUSES = ("pending", "spec_ready", "in_progress", "blocked", "done")
AUDIT_LEVELS = ("basic", "standard", "strict")
NAME_RE = re.compile(r"^[a-z0-9_]+$")


def main(argv: list[str]) -> int:
    as_json = False
    path: str | None = None
    for a in argv:
        if a == "--json":
            as_json = True
        elif a.startswith("-"):
            print(f"unknown argument: {a}", file=sys.stderr)
            return 2
        else:
            if path is not None:
                print("usage: validate-feature-list.py [--json] <feature-list.json>", file=sys.stderr)
                return 2
            path = a
    if path is None:
        print("usage: validate-feature-list.py [--json] <feature-list.json>", file=sys.stderr)
        return 2

    errors: list[dict[str, str]] = []

    def err(path_in_doc: str, code: str, message: str) -> None:
        errors.append({"path": path_in_doc, "code": code, "message": message})

    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"file not found: {path}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        err("", "invalid_json", f"not valid JSON: {e}")
        data = None

    if isinstance(data, dict):
        project = data.get("project")
        if not isinstance(project, dict):
            err("project", "missing", "project section is required")
        else:
            name = project.get("name")
            if not isinstance(name, str) or not name:
                err("project.name", "missing", "project.name must be a non-empty string")
            if not isinstance(project.get("parallel"), bool):
                err("project.parallel", "invalid_type", "project.parallel must be a boolean")
            modules = project.get("modules")
            if not isinstance(modules, list) or not all(isinstance(m, str) for m in modules):
                err("project.modules", "invalid_type", "project.modules must be an array of strings")
            level = project.get("audit_level")
            if level not in AUDIT_LEVELS:
                err("project.audit_level", "invalid_enum", f"audit_level must be one of {AUDIT_LEVELS}")

        features = data.get("features")
        if not isinstance(features, list):
            err("features", "missing", "features array is required")
        else:
            seen_ids: set[int] = set()
            in_progress = 0
            for i, feat in enumerate(features):
                at = f"features[{i}]"
                if not isinstance(feat, dict):
                    err(at, "invalid_type", "feature must be an object")
                    continue
                fid = feat.get("id")
                if not isinstance(fid, int) or isinstance(fid, bool):
                    err(f"{at}.id", "invalid_type", "id must be an integer")
                elif fid in seen_ids:
                    err(f"{at}.id", "duplicate", f"duplicate feature id {fid}")
                else:
                    seen_ids.add(fid)
                fname = feat.get("name")
                if not isinstance(fname, str) or not NAME_RE.match(fname):
                    err(f"{at}.name", "invalid_name", "name must be snake_case ([a-z0-9_]+)")
                for key in ("title", "description"):
                    if not isinstance(feat.get(key), str):
                        err(f"{at}.{key}", "invalid_type", f"{key} must be a string")
                acc = feat.get("acceptance")
                if not isinstance(acc, list) or not all(isinstance(a, str) for a in acc):
                    err(f"{at}.acceptance", "invalid_type", "acceptance must be an array of strings")
                status = feat.get("status")
                if status not in STATUSES:
                    err(f"{at}.status", "invalid_enum", f"status must be one of {STATUSES}")
                elif status == "in_progress":
                    in_progress += 1
            if in_progress > 1:
                err("features", "invariant_I1", f"at most one feature may be in_progress (found {in_progress})")
    elif data is not None:
        err("", "invalid_type", "document must be an object")

    if as_json:
        print(json.dumps({
            "tool": "validate-feature-list",
            "protocol": 1,
            "valid": not errors,
            "errors": errors,
        }))
    else:
        if errors:
            for e in errors:
                where = e["path"] or "(document)"
                print(f"[FAIL] {where}: {e['message']}")
            print(f"{len(errors)} error(s)")
        else:
            print("feature_list.json is valid (protocol v1)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 5: Wire the installer**

In `init.sh`:

a) In the `# Everything else groups under harness/` copy block, after `mkdir -p harness/progress harness/specs` add:

```bash
mkdir -p harness/tools
cp "$TEMPLATES_DIR/tools/validate-feature-list.py" ./harness/tools/
chmod +x ./harness/tools/validate-feature-list.py
```

b) In the validation section, after `check_file "harness/feature_list.json"` add:

```bash
if command -v python3 >/dev/null 2>&1; then
  if python3 ./harness/tools/validate-feature-list.py ./harness/feature_list.json > /dev/null 2>&1; then
    ok "feature_list.json is valid (protocol v1)"
  else
    warn "feature_list.json does not satisfy protocol v1 — run: python3 harness/tools/validate-feature-list.py harness/feature_list.json"
  fi
fi
```

(Warn, never fail: a kept user file with extra keys must not block a --force reinstall.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -2`
Expected: `PASS: 230  FAIL: 0` (220 + 10 new: 8 in the validator test, +2 net in the updated default test).

- [ ] **Step 7: Commit**

```bash
git add templates/feature_list.schema.json templates/tools init.sh tests/test-install.sh
git commit -m "feat: feature_list protocol v1 schema, stdlib validator, core tools in harness/tools/"
```

---

### Task 6: check-traceability.py

**Files:**
- Create: `templates/tools/check-traceability.py` (executable source)
- Modify: `init.sh` (install the checker next to the validator)
- Test: `tests/test-install.sh` (1 new test function)

**Interfaces:**
- Consumes: the impl-table convention (specs.md §Traceability) and requirements `R<n>` ids.
- Produces: `python3 harness/tools/check-traceability.py [--feature NAME] [--all] [--json] [root]` — exit 0 covered / 1 gaps / 2 usage; JSON per Task 1 §5.

- [ ] **Step 1: Write the failing test**

```bash
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
}
```

Call in Main after `test_feature_list_validator`:

```bash
test_traceability_checker
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 1` — the installer runs green (core tools dir exists but the checker is not installed yet by init.sh), the guard block reports "checker not installed" and returns early.

- [ ] **Step 3: Create the checker**

`templates/tools/check-traceability.py` (chmod +x; stdlib only):

```python
#!/usr/bin/env python3
"""Check requirement traceability for harness specs (Protocol v1).

For each feature with a spec (harness/specs/<name>/requirements.md), collects
the R<n> identifiers, merges the traceability tables from every
harness/progress/impl_*.md, and verifies:
  1. every R<n> appears in at least one table row;
  2. every test identifier referenced by a row exists literally under tests/
     (file name or file content match).

Usage:
  check-traceability.py --all [--json] [root]
  check-traceability.py --feature NAME [--json] [root]

Exit codes: 0 covered, 1 gaps, 2 usage error.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REQ_RE = re.compile(r"\bR(\d+)\b")
ROW_RE = re.compile(r"^\|\s*(R\d+)\s*\|([^|]*)\|")


def find_requirements(root: Path, feature: str) -> set[str]:
    req_file = root / "harness" / "specs" / feature / "requirements.md"
    if not req_file.is_file():
        return set()
    return {f"R{m}" for m in REQ_RE.findall(req_file.read_text(encoding="utf-8"))}


def collect_tables(root: Path) -> dict[str, dict[str, list[str]]]:
    """Merge every impl_*.md table into {requirement: [test identifiers]}."""
    merged: dict[str, list[str]] = {}
    progress = root / "harness" / "progress"
    if not progress.is_dir():
        return merged
    for impl in sorted(progress.glob("impl_*.md")):
        for line in impl.read_text(encoding="utf-8").splitlines():
            m = ROW_RE.match(line)
            if m is None:
                continue
            req = m.group(1)
            tests = [t for t in re.split(r"[,\s]+", m.group(2).strip()) if t]
            merged.setdefault(req, [])
            for t in tests:
                if t not in merged[req]:
                    merged[req].append(t)
    return merged


def test_identifier_exists(root: Path, identifier: str) -> bool:
    tests_dir = root / "tests"
    if not tests_dir.is_dir():
        return False
    for tf in tests_dir.rglob("*.py"):
        if identifier in tf.name or identifier in tf.read_text(encoding="utf-8"):
            return True
    return False


def check_feature(root: Path, feature: str) -> dict:
    requirements = find_requirements(root, feature)
    tables = collect_tables(root)
    gaps: list[dict[str, str]] = []
    unresolved: list[str] = []
    covered = 0
    for req in sorted(requirements, key=lambda r: int(r[1:])):
        tests = tables.get(req)
        if not tests:
            gaps.append({"requirement": req, "reason": "not present in any impl traceability table"})
            continue
        missing = [t for t in tests if not test_identifier_exists(root, t)]
        if missing:
            gaps.append({"requirement": req, "reason": f"test identifier(s) not found under tests/: {', '.join(missing)}"})
            continue
        covered += 1
    for req, tests in sorted(tables.items()):
        if requirements and req not in requirements:
            unresolved.append(req)
    return {
        "name": feature,
        "requirements": len(requirements),
        "covered": covered,
        "gaps": gaps,
        "unresolved": unresolved,
    }


def main(argv: list[str]) -> int:
    as_json = False
    feature: str | None = None
    all_features = False
    root = Path.cwd()
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--json":
            as_json = True
        elif a == "--all":
            all_features = True
        elif a == "--feature":
            i += 1
            if i >= len(argv):
                print("error: --feature requires a name", file=sys.stderr)
                return 2
            feature = argv[i]
        elif a == "--root":
            i += 1
            if i >= len(argv):
                print("error: --root requires a path", file=sys.stderr)
                return 2
            root = Path(argv[i])
        elif a.startswith("-"):
            print(f"unknown argument: {a}", file=sys.stderr)
            return 2
        else:
            root = Path(a)
        i += 1
    if not all_features and feature is None:
        print("usage: check-traceability.py --all | --feature NAME [--json] [root]", file=sys.stderr)
        return 2

    specs_dir = root / "harness" / "specs"
    if all_features:
        names = sorted(p.name for p in specs_dir.iterdir() if p.is_dir()) if specs_dir.is_dir() else []
    else:
        names = [feature]

    results = [check_feature(root, n) for n in names]
    verdict = "PASS" if all(r["gaps"] == [] for r in results) else "FAIL"

    if as_json:
        print(json.dumps({
            "tool": "check-traceability",
            "protocol": 1,
            "verdict": verdict,
            "features": results,
        }))
    else:
        for r in results:
            print(f"## {r['name']}: {r['covered']}/{r['requirements']} requirements covered")
            for g in r["gaps"]:
                print(f"  [GAP] {g['requirement']}: {g['reason']}")
        print(f"VERDICT: {verdict}")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 4: Wire the installer**

In `init.sh`, immediately after the validator copy line (`chmod +x ./harness/tools/validate-feature-list.py`) add:

```bash
cp "$TEMPLATES_DIR/tools/check-traceability.py" ./harness/tools/
chmod +x ./harness/tools/check-traceability.py
```

(No validation-section entry: with no features the checker is trivially PASS; the reviewer runs it per §Task 7.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -2`
Expected: `PASS: 239  FAIL: 0` (230 + 9 new assertions: install, guard, gap-red, R2 grep, json run, shape, all-pass run, verdict grep, ghost-red).

- [ ] **Step 6: Commit**

```bash
git add templates/tools/check-traceability.py init.sh tests/test-install.sh
git commit -m "feat: traceability checker (R<n> vs impl tables vs tests) installed as core tool"
```

---

### Task 7: eval fixtures + reviewer conditional + README

**Files:**
- Create: `evals-fixtures/README.md`, `evals-fixtures/01-traceability-clean/`, `evals-fixtures/02-traceability-gap/`, `evals-fixtures/03-planted-security-bug/`
- Modify: `templates/.claude/agents/reviewer.md`, `templates/.opencode/agent/reviewer.md` (one identical conditional line each)
- Modify: `README.md` (machine-interface section)
- Test: `tests/test-install.sh` (1 new test function)

**Interfaces:**
- Consumes: Task 6 checker, Task 2 audit script, Protocol v1.
- Produces: frozen corpus for `harness-graph` phase 4; reviewer instructions gated on `harness/tools/check-traceability.py` presence (same pattern as the module conditionals).

- [ ] **Step 1: Write the failing test**

```bash
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
```

Call in Main after `test_traceability_checker`:

```bash
test_evals_fixtures
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 1` ("evals-fixtures does not exist").

- [ ] **Step 3: Create the fixtures**

`evals-fixtures/README.md`:

````markdown
# Eval fixtures (frozen corpus)

Deterministic scenarios with known expected outcomes. Consumers: harness-standard's
own test suite, and `harness-graph` phase-4 evals. Fixtures are versioned with the
repo — changing a fixture invalidates historical eval results.

| Fixture | Tool under test | Command | Expected |
|---|---|---|---|
| `01-traceability-clean` | `check-traceability.py` | `--feature feat-a --json` | exit 0, `verdict: PASS` |
| `02-traceability-gap` | `check-traceability.py` | `--feature feat-a --json` | exit 1, `verdict: FAIL`, gap `R2` |
| `03-planted-security-bug` | `audit-security.sh --json` | from `project/` | exit 1, `verdict: REJECT` (requires `bandit` installed) |

Each fixture ships `project/` (a minimal harness layout slice) and `EXPECTED.md`
(the ground truth).
````

`evals-fixtures/01-traceability-clean/EXPECTED.md`:

````markdown
# Expected outcome — 01-traceability-clean

- Tool: `python3 harness/tools/check-traceability.py --feature feat-a --json`
- Exit code: 0
- Verdict: PASS
- Shape: `features[0].requirements == 2`, `covered == 2`, `gaps == []`
````

`evals-fixtures/01-traceability-clean/project/harness/specs/feat-a/requirements.md`:

````markdown
# Requirements — feat-a

- R1: WHEN the user submits an empty cart, the system SHALL return an error.
- R2: The system SHALL persist a valid order.
````

`evals-fixtures/01-traceability-clean/project/harness/progress/impl_session1.md`:

````markdown
| Requirement | Test(s)                      | Implementation file(s) | Status |
|-------------|------------------------------|------------------------|--------|
| R1          | test_empty_cart              | src/core/cart.py       | done   |
| R2          | test_empty_cart, test_persist| src/core/orders.py     | done   |
````

`evals-fixtures/01-traceability-clean/project/tests/test_cart.py`:

````python
def test_empty_cart():
    assert True


def test_persist():
    assert True
````

`evals-fixtures/02-traceability-gap/EXPECTED.md`:

````markdown
# Expected outcome — 02-traceability-gap

- Tool: `python3 harness/tools/check-traceability.py --feature feat-a --json`
- Exit code: 1
- Verdict: FAIL
- Shape: `features[0].gaps` contains an entry with `requirement == "R2"` (R2 absent
  from the impl table).
````

`evals-fixtures/02-traceability-gap/project/harness/specs/feat-a/requirements.md`: identical content to 01's requirements.

`evals-fixtures/02-traceability-gap/project/harness/progress/impl_session1.md`:

````markdown
| Requirement | Test(s)         | Implementation file(s) | Status |
|-------------|-----------------|------------------------|--------|
| R1          | test_empty_cart | src/core/cart.py       | done   |
````

`evals-fixtures/02-traceability-gap/project/tests/test_cart.py`:

````python
def test_empty_cart():
    assert True
````

`evals-fixtures/03-planted-security-bug/EXPECTED.md`:

````markdown
# Expected outcome — 03-planted-security-bug

- Tool: `bash harness/tools/audit-security.sh --json` (run from `project/`, python stack)
- Exit code: 1
- Verdict: REJECT
- Requires: `bandit` installed (findings include a HIGH from `src/core/db.py`).
  Without bandit the run degrades to `skipped: ["bandit: not installed"]` and
  verdict PASS — consumers must assert findings, not only the verdict, when
  bandit is available.
- Planted defect: SQL string concatenation + hardcoded credential in
  `src/core/db.py` (bandit B608 / B105 territory).
````

`evals-fixtures/03-planted-security-bug/project/src/core/db.py`:

````python
"""Data access — contains an INTENTIONALLY planted security defect. Do not fix."""


def get_user(cursor, user_id):
    # PLANTED BUG: SQL built by string concatenation (injection).
    query = "SELECT * FROM users WHERE id = '%s'" % user_id
    return cursor.execute(query).fetchone()


def connect():
    import sqlite3

    # PLANTED BUG: hardcoded credential.
    return sqlite3.connect("app.db")
````

(No `requirements.txt` in fixture 03's project — the audit script auto-detects the stack from the file layout; give it one: create `evals-fixtures/03-planted-security-bug/project/requirements.txt` as an empty file so detection lands on python.)

- [ ] **Step 4: Reviewer conditional (both copies, identical line)**

In `templates/.claude/agents/reviewer.md` and `templates/.opencode/agent/reviewer.md`, inside the `## Conditional audits` section, append this bullet after the `strict` bullet:

````markdown
- **Traceability (when `harness/tools/check-traceability.py` exists)** — run
  `python3 harness/tools/check-traceability.py --all` before the verdict. A
  non-zero exit (coverage gaps) rejects the approval. Your semantic judgment
  (does the test really verify the requirement?) still applies on top — the
  script only proves the mapping exists.
````

- [ ] **Step 5: README machine-interface section**

In `README.md`, after the "### Optional capability modules" section, add:

````markdown
### Machine interface (Protocol v1)

`docs/protocol.md` is the machine-facing contract: file formats, invariants, and
the JSON output of the deterministic tools. Any orchestrator (human, Claude Code,
opencode, or an external graph runtime) can consume a harness install:

```bash
python3 harness/tools/validate-feature-list.py --json harness/feature_list.json
python3 harness/tools/check-traceability.py --all --json
bash harness/tools/audit-security.sh --json   # security-audit module
bash harness/tools/bench.sh --json            # performance-benchmarks module
python3 harness/tools/scan.py --json --summary  # project-scanner module
```

The frozen eval scenarios live in `evals-fixtures/` with their expected outcomes.
````

- [ ] **Step 6: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -2`
Expected: `PASS: 248  FAIL: 0` (239 + 9 new assertions).

- [ ] **Step 7: Commit**

```bash
git add evals-fixtures templates/.claude/agents/reviewer.md templates/.opencode/agent/reviewer.md README.md tests/test-install.sh
git commit -m "feat: frozen eval fixtures, reviewer traceability gate, machine-interface docs"
```

---

## Spec coverage check (self-review)

| Approved design item | Task |
|---|---|
| `docs/protocol.md` protocol v1 | Task 1 |
| `--json` audit-security.sh (+ real exit 2) | Task 2 |
| `--json` bench.sh (+ regression list) | Task 3 |
| `--json` scan.py (all commands) | Task 4 |
| feature_list JSON Schema + stdlib validator + installer core tools | Task 5 |
| check-traceability.py (uses existing impl-table convention) | Task 6 |
| evals-fixtures + reviewer conditional + README | Task 7 |

Deliberate decisions (already approved in design conversation, restated):
1. Traceability checker validates the EXISTING `impl_*.md` table convention — no new convention.
2. Validator enforces protocol rules in stdlib code; the JSON Schema file is the documented contract (jsonschema lib deliberately not required on installed projects).
3. `harness/tools/` now always exists (core tools), even with zero modules installed — `test_default_install_no_modules` updated accordingly.
4. Fixture 03's planted bug is only exercised structurally by the suite (bandit availability is not assumed); harness-graph's evals assert findings when bandit exists.
5. Default `--json`-less output of every script is byte-identical to today.
