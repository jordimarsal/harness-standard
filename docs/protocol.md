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
