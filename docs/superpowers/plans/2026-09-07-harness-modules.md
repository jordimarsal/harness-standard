# Optional Capability Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `agent_prompt.md` + `annex.md` into seven optional installable modules under `templates/modules/`, wired into `init.sh` (flags + mandatory interactive menu), the role templates, and the test suite.

**Architecture:** Data-driven installer: each module is a directory with a `manifest.json` (inject list) plus content files. `init.sh` discovers manifests, parses them with pure sed/grep (no jq/python dependency at install time), and injects files with three modes: `copy`, `copy-if-missing`, `append-section` (marker-scoped so `--force` never duplicates). Role templates gain file-presence-gated conditional instructions (no new roles, no new states).

**Tech Stack:** Bash (installer + installer tests), Python 3 stdlib (scan.py only), Markdown content. No new runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-09-06-harness-modules-design.md` — read it alongside this plan; section references below (`§N`) point at the spec.

## Global Constraints

- `init.sh` must stay dependency-free: bash, coreutils, sed, grep, awk only. **No jq, no python3 at install time.** (`scan.py` needs python3 at *review* time only; leader logs and continues if missing.)
- `audit-security.sh` and `bench.sh` are run by the reviewer, **never inside `init.sh`** (§5).
- Default install (no flags, no answers): identical files/stdout to the current installer **except** `"modules": []` and `"audit_level": "basic"` keys in `harness/feature_list.json` (§4.2).
- Tests never make network calls; Wekan tests are file assertions only (§8.6).
- All file content in English (repo convention).
- No secrets in any committed file. `harness/wekan.json` has config only; credentials live in a gitignored env file (§4.7).
- Manifest format discipline (required by the pure-bash parser):
  - `name`, `description`, `stacks`, `verify` each on their own line; `stacks` and `verify` are one-line arrays.
  - Each `injects[]` entry on **its own line**, keys in order `src`, `dst`, `mode`.
  - Descriptions must not contain the quoted words `"name"`, `"src"`, `"dst"`, `"mode"`, `"stacks"`, `"verify"`.
- Existing `harness/feature_list.json` is user state: on `--force` reinstall its feature data is preserved, but the installer best-effort refreshes the `modules`/`audit_level` keys to match the current run's selection (Task 8). Files of unselected modules are NOT deleted (known limitation, documented in Task 12).
- Every task ends with `bash tests/test-install.sh` fully green (existing 110 PASS + new tests).

## File Structure

```
docs/reference/                                  # Task 1: archived source material
templates/modules/
├── _shared/c7-audit.md                          # C7 checkpoint source (no manifest → never listed)
├── architecture-catalog/{manifest.json, architecture-options.md}
├── iterative-refinement/{manifest.json, iteration-protocol.md}
├── decision-memory/{manifest.json, ADR-template.md}
├── project-scanner/{manifest.json, scan.py}
├── security-audit/{manifest.json, verification-audit.md, audit-security.sh}
├── performance-benchmarks/{manifest.json, verification-benchmarks.md, bench.sh, baselines.json}
└── wekan-tickets/{manifest.json, SKILL.md, wekan.json}
init.sh                                          # Tasks 4, 6, 10
tests/test-install.sh                            # every task after 1
templates/feature_list.json                      # Task 4
templates/AGENTS.md                              # Task 11
templates/.claude/agents/{spec-author,reviewer,leader}.md   # Task 11
templates/.opencode/agent/{spec-author,reviewer,leader}.md  # Task 11
README.md                                        # Task 12
```

---

### Task 1: Archive source documents

The spec (§7) moves the two source documents to `docs/reference/` for traceability. They are currently **untracked**, so use `mv` (not `git mv`).

**Files:**
- Move: `agent_prompt.md` → `docs/reference/agent_prompt.md`
- Move: `annex.md` → `docs/reference/annex.md`

- [ ] **Step 1: Move the files**

```bash
mkdir -p docs/reference
mv agent_prompt.md docs/reference/agent_prompt.md
mv annex.md docs/reference/annex.md
```

- [ ] **Step 2: Verify nothing references them at the old paths**

Run: `grep -rn "agent_prompt.md\|annex.md" --include="*.sh" --include="*.json" . | grep -v docs/reference | grep -v '\.git/'`
Expected: no matches (the spec references them only in prose).

- [ ] **Step 3: Run the suite (must stay green)**

Run: `bash tests/test-install.sh`
Expected: `PASS: 110  FAIL: 0`

- [ ] **Step 4: Commit**

```bash
git add docs/reference/
git commit -m "chore: archive module source material under docs/reference/"
```

---

### Task 2: Manifest validation test + architecture-catalog module

First test of spec §8.3 (manifests parse, required keys, referenced files exist). It fails until the module exists. Also delivers the first content module (spec §3 tree: `architecture-catalog`).

**Files:**
- Create: `templates/modules/architecture-catalog/manifest.json`
- Create: `templates/modules/architecture-catalog/architecture-options.md`
- Test: `tests/test-install.sh` (new function + main call)

**Interfaces:**
- Produces: manifest format consumed by the Task 4 parser (Global Constraints discipline); module name `architecture-catalog` used by later tests.

- [ ] **Step 1: Write the failing test**

Add after the `test_force_switch_tool` function in `tests/test-install.sh`:

```bash
test_module_manifests_valid() {
  local t="every module manifest parses and its referenced files exist"
  run_test "$t"
  if [ ! -d "$REPO_DIR/templates/modules" ]; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: templates/modules missing")
    echo "    FAIL: templates/modules does not exist"
    return
  fi
  local n=0
  for mf in "$REPO_DIR"/templates/modules/*/manifest.json; do
    [ -e "$mf" ] || continue
    n=$((n + 1))
    if python3 - "$mf" "$(dirname "$mf")" <<'PYEOF' >/dev/null 2>&1; then
import json, os, sys
mf, mdir = sys.argv[1], sys.argv[2]
data = json.load(open(mf))
required = {"name", "description", "stacks", "injects", "verify"}
missing = required - set(data)
assert not missing, f"missing keys: {missing}"
assert isinstance(data["stacks"], list) and data["stacks"], "stacks must be a non-empty list"
for inj in data["injects"]:
    assert {"src", "dst", "mode"} <= set(inj), f"bad inject: {inj}"
    assert os.path.isfile(os.path.join(mdir, inj["src"])), f"missing src file: {inj['src']}"
for v in data["verify"]:
    assert isinstance(v, str)
    assert not v.startswith("/"), f"verify path must be project-relative: {v}"
sys.exit(0)
PYEOF
      PASS=$((PASS + 1))
    else
      FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: invalid manifest $mf")
      echo "    FAIL: invalid manifest: $mf"
    fi
  done
  if [ "$n" -eq 0 ]; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: no module manifests found")
    echo "    FAIL: no module manifests found"
  fi
}
```

Add to the Main section, after the `test_python_stack` call:

```bash
test_module_manifests_valid
```

Note: this test requires `python3` in the dev/test environment (available; scan.py tests in Task 5 need it too).

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 1` with "templates/modules does not exist".

- [ ] **Step 3: Create the manifest**

`templates/modules/architecture-catalog/manifest.json`:

```json
{
  "name": "architecture-catalog",
  "description": "Reference catalog of architecture options for design decisions",
  "stacks": ["typescript", "node", "android", "java", "python", "rust", "generic"],
  "injects": [
    { "src": "architecture-options.md", "dst": "docs/architecture-options.md", "mode": "copy" }
  ],
  "verify": ["docs/architecture-options.md"]
}
```

- [ ] **Step 4: Create the catalog content**

`templates/modules/architecture-catalog/architecture-options.md`:

````markdown
# Architecture Options Catalog

> Installed by the harness `architecture-catalog` module. Reference material for
> `design.md` Architectural Decisions sections. Consult it when relevant — it does
> not force a choice for every task.

Each option lists what it is, when it fits, its trade-offs, and when NOT to use it.

## Core system patterns

### Layered Architecture (Traditional)
- **What:** Presentation → Business → Persistence; calls go downward only.
- **Best for:** CRUD applications, simple monoliths, rapid prototyping.
- **Trade-offs:** Low complexity; tight coupling; hard to test in isolation.
- **When NOT to use:** Complex domain logic that changes independently of delivery
  mechanisms; when you need to swap infrastructure (DB, transport) freely.

### Hexagonal Architecture (Ports & Adapters)
- **What:** Core domain logic isolated behind Ports (interfaces); Adapters implement
  them for the outside world (DB, HTTP, CLI).
- **Best for:** Complex business logic, long-term maintainability, DDD.
- **Trade-offs:** Higher initial complexity; more files; steeper learning curve.
- **When NOT to use:** Thin CRUD layers where the "domain" is the database schema;
  throwaway prototypes.

### Clean Architecture
- **What:** Entities → Use Cases → Interface Adapters → Frameworks/Drivers; outer
  layers depend on inner, never reverse.
- **Best for:** Large enterprise systems, multiple delivery mechanisms.
- **Trade-offs:** Significant boilerplate; risk of over-engineering.
- **When NOT to use:** Small services; teams without the discipline to keep the
  dependency rule (it decays into Layered quickly).

### CQRS (Command Query Responsibility Segregation)
- **What:** Separate read and write models; commands mutate, queries project.
- **Best for:** High-throughput systems, complex reporting needs.
- **Trade-offs:** Eventual consistency; duplicated logic; operational complexity.
- **When NOT to use:** When read and write sides are the same shape (most CRUD);
  no real need for independent scaling of reads/writes.

### Microservices
- **What:** Deployment units decomposed by bounded context; independent lifecycles.
- **Best for:** Large teams, independent scaling, polyglot persistence.
- **Trade-offs:** Network latency; distributed transactions; DevOps overhead.
- **When NOT to use:** Small teams; unclear domain boundaries; no container/orchestration
  maturity — a modular monolith delivers most benefits without the tax.

### Modular Monolith
- **What:** One deployable, internally split into modules with enforced boundaries
  and explicit public surfaces.
- **Best for:** Most products until scale proves otherwise; teams of 1-15.
- **Trade-offs:** Discipline needed to prevent boundary erosion; single-runtime
  scaling limits.
- **When NOT to use:** Modules with radically different scaling or availability
  requirements; hard team ownership borders that CI cannot enforce.

### Event-Driven Architecture
- **What:** State changes emitted as events; consumers react asynchronously.
- **Best for:** Real-time systems, audit trails, decoupled workflows.
- **Trade-offs:** Harder to debug; eventual consistency; event schema versioning.
- **When NOT to use:** When callers need synchronous answers; low event volume
  where a direct call plus an outbox table is enough.

### Functional Core / Imperative Shell
- **What:** Pure decision-making core; side effects (I/O) pushed to a thin shell.
- **Best for:** Data pipelines, transformations, highly testable business logic.
- **Trade-offs:** Requires discipline; less OOP-friendly; mapping layers at edges.
- **When NOT to use:** Effect-dominated code (thin CRUD controllers) where the core
  would be empty.

## Specialized patterns

### API styles
| Style | Best for | Avoid when |
|---|---|---|
| REST | Resource-oriented CRUD, public APIs | Fine-grained field selection or many round trips needed |
| GraphQL | Client-specified fields, aggregated views | Simple resources; strict caching requirements |
| gRPC | Internal service-to-service, high throughput, streaming | Browser-facing public APIs (needs a gateway) |
| WebSocket | Real-time bidirectional (chat, live dashboards) | Request/response semantics suffice |

### Frontend integration
| Pattern | Best for | Avoid when |
|---|---|---|
| MVC | Traditional server-rendered web | Heavy client-side state |
| MVVM | Reactive UIs with two-way binding | Simple static views |
| Clean + Redux | Unidirectional data flow, complex app state | Small apps (ceremony outweighs benefit) |
| BFF | API tailored to one UI's needs | Single client type |

### Data persistence
| Pattern | Best for | Avoid when |
|---|---|---|
| Repository | Abstracting data access behind a domain interface | The ORM already is the abstraction and leaks are acceptable |
| Unit of Work | Transactional consistency across aggregates | Single-aggregate transactions only |
| Event Sourcing | Full audit trail, temporal queries | The team cannot own event versioning and replays |
| CQRS | Read/write shapes diverge significantly | They do not (see above) |

## Selection guidance

Choose at most ONE core system pattern per service and justify with: complexity,
team size, scalability needs. If unsure between two, write both as alternatives in
`design.md` with pros/cons and pick one — the reviewer challenges the justification,
not the choice itself.
````

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `PASS: 111  FAIL: 0` (the installer is not touched yet, so `architecture-options.md` is not installed anywhere — that is Task 4).

- [ ] **Step 6: Commit**

```bash
git add templates/modules tests/test-install.sh
git commit -m "feat: architecture-catalog module and manifest validation test"
```

---

### Task 3: iterative-refinement + decision-memory modules

Two more static content modules (spec §3 tree). Content migrates `agent_prompt.md` §§1-7 with the §6.1 corrections applied (adaptive rounds, real verification commands, adversarial review moved to reviewer), and replaces the annex C JSON memory system with ADR markdown files (§6.2 row: "JSON memory system dropped entirely").

**Files:**
- Create: `templates/modules/iterative-refinement/manifest.json`
- Create: `templates/modules/iterative-refinement/iteration-protocol.md`
- Create: `templates/modules/decision-memory/manifest.json`
- Create: `templates/modules/decision-memory/ADR-template.md`

**Interfaces:**
- Produces: module names `iterative-refinement`, `decision-memory`; destinations `docs/iteration-protocol.md`, `harness/decisions/_template.md` — both referenced by Task 11 role-template conditional instructions ("if `docs/architecture-options.md` exists", "if `harness/decisions/_template.md` exists").

- [ ] **Step 1: Create the manifests**

`templates/modules/iterative-refinement/manifest.json`:

```json
{
  "name": "iterative-refinement",
  "description": "Adaptive iteration protocol with self-review and adversarial checklist",
  "stacks": ["typescript", "node", "android", "java", "python", "rust", "generic"],
  "injects": [
    { "src": "iteration-protocol.md", "dst": "docs/iteration-protocol.md", "mode": "copy" }
  ],
  "verify": ["docs/iteration-protocol.md"]
}
```

`templates/modules/decision-memory/manifest.json`:

```json
{
  "name": "decision-memory",
  "description": "ADR files for decisions worth remembering beyond a feature",
  "stacks": ["typescript", "node", "android", "java", "python", "rust", "generic"],
  "injects": [
    { "src": "ADR-template.md", "dst": "harness/decisions/_template.md", "mode": "copy-if-missing" }
  ],
  "verify": ["harness/decisions/_template.md"]
}
```

- [ ] **Step 2: Create the iteration protocol**

`templates/modules/iterative-refinement/iteration-protocol.md`:

````markdown
# Iteration Protocol (Adaptive)

> Installed by the harness `iterative-refinement` module. The implementer follows
> this protocol when implementing a feature; the reviewer uses its adversarial
> checklist. Scale the loop depth to feature size — do not run full rounds on a
> one-file change.

## Choose the loop depth (aligned with the leader's effort scaling table)

| Feature size | Loop |
|---|---|
| Trivial (1 file) | Single pass: implement → verify → report |
| Medium (2-3 files) | One refinement round: implement → self-review → fix → verify |
| Complex / very complex | Full rounds below |

## Full rounds (complex features)

### Round 1 — Initial implementation
Produce a complete, working implementation with tests. Note assumptions,
trade-offs, and known limitations in the iteration report.

### Round 2 — Self-review
Apply the quality checklist below. Identify 3-5 concrete improvement areas, fix
them, and document what changed and why.

### Round 3 — Adversarial review (reviewer)
The reviewer challenges the implementation with the adversarial checklist below.
Every finding is either fixed or explicitly defended with rationale in the review
file. The reviewer is a separate agent — self-review never substitutes for it.

### Round 4 — Verification deep dive
Run the real verification commands (never "mentally"):

- Coverage: `python3 -m pytest -q tests --cov=<pkg> --cov-report=term-missing`
  (stack equivalents: `vitest --coverage`, `cargo llvm-cov`, `mvn jacoco:report`).
- Lint and types: `ruff check .` + `mypy --check-untyped-defs .` (stack equivalents:
  `eslint`, `cargo clippy`, `checkstyle/spotbugs`).
- Add tests for untested branches, error paths, and edge cases.

Default coverage targets: 100% domain models, >= 90% services, >= 80% adapters.
Projects override these in `docs/verification.md`; this module never edits that
file.

### Round 5 — Final refinement
Performance, readability, documentation. Re-run the stack quality gates. Only
then request review.

## Adversarial checklist (reviewer)

1. Security: what if a malicious actor provides this input?
2. Performance: what happens with 10,000 concurrent requests?
3. Maintainability: will a junior developer understand this in 6 months?
4. Edge cases: null, empty, negative, unexpected values?
5. Concurrency: is this threadsafe? Any race conditions?
6. Dependencies: could we reduce external dependencies?
7. Testing: is this test brittle? Does it depend on implementation details?

Each finding → fix the code OR document the decision with rationale.

## Quality self-review checklist (implementer, after each round)

1. Architecture decision made and justified (if the feature has one).
2. SOLID principles applied where they reduce, not add, complexity.
3. Type hints / static types pass the stack checker.
4. Dataclasses/Enums/value objects over raw dicts.
5. No blanket `except Exception:`; specific errors raised and caught.
6. Logs use lazy formatting; no secrets in logs.
7. Tests cover happy path, edge cases, and error cases.
8. Test names in English, describing behavior.
9. I/O at the edges; core logic pure.
10. No circular imports; no global state.
11. No nested functions unless closing over a local value.
12. No debug prints, no context-free TODOs.

## Iteration report (appended to `harness/progress/current.md`)

```markdown
## Iteration #N — <phase>
- Changes made: <concrete list>
- Verification: <commands run + result summary>
- Checklist: 12/12 verified (or list the exceptions with reasons)
- Remaining concerns: <for the next iteration or the reviewer>
```
````

- [ ] **Step 3: Create the ADR template**

`templates/modules/decision-memory/ADR-template.md`:

````markdown
# ADR-NNNN: <short title of the decision>

- **Date:** YYYY-MM-DD
- **Status:** proposed | accepted | superseded by ADR-XXXX
- **Feature:** <feature name, or "project-level">

## Context

What forces are in play — technical, organizational, deadlines. State the problem,
not the solution.

## Decision

The decision itself, in one or two sentences, active voice.

## Alternatives considered

For each alternative: what it was, why it was rejected (one or two lines).

## Consequences

What becomes easier, what becomes harder, what must now be true. Include the
reversibility cost ("cheap to reverse" / "expensive — revisit before changing").
````

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `PASS: 113  FAIL: 0` (3 modules × 1 manifest assertion).

- [ ] **Step 5: Commit**

```bash
git add templates/modules
git commit -m "feat: iterative-refinement and decision-memory modules"
```

---

### Task 4: Installer core — flags, manifest parsing, injection, feature_list keys

The heart of §4.2: `--modules=a,b`, `--audit-level=`, manifest parsing (pure sed/grep), the three injection modes with markers, `{{MODULES}}`/`{{AUDIT_LEVEL}}` in `feature_list.json`, stack filtering with warning, and per-module validation. The interactive menu comes in Task 10; C7 injection in Task 6.

**Files:**
- Modify: `init.sh` (usage line 4; argument loop lines 44-56; new sections after line ~118 and before line ~159; injection after line ~229; validation after line ~278)
- Modify: `templates/feature_list.json`
- Test: `tests/test-install.sh` (2 helpers + 4 test functions)

**Interfaces:**
- Consumes: manifest format locked in Tasks 2-3.
- Produces (init.sh internals, reused by Tasks 6/10): `MODULES_SELECTED` array, `AUDIT_LEVEL` variable, functions `manifest_str`, `manifest_list`, `manifest_injects`, `module_supports_stack`, `inject_append_section`, `inject_module`. Section markers `<!-- harness:module:<name>:start -->` / `<!-- harness:module:<name>:end -->` relied on by Task 8 force-tests.

- [ ] **Step 1: Add test helpers**

Add after `assert_executable` in `tests/test-install.sh`:

```bash
assert_count() {  # assert_count <name> <pattern> <file> <expected-count>
  local got
  got=$(grep -c "$2" "$3" 2>/dev/null || true)
  if [ "$got" -eq "$4" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: expected $4 of '$2' in $3, got $got")
    echo "    FAIL: '$2' appears $got times in $3 (expected $4)"
  fi
}

assert_no_dir() {  # assert_no_dir <name> <path>
  if [ ! -d "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1: dir $2 should not exist")
    echo "    FAIL: dir $2 should not exist"
  fi
}
```

- [ ] **Step 2: Write the failing tests**

Add after the Task 2 test function:

```bash
test_modules_install() {
  local t="--modules installs module files and records them in feature_list.json"
  run_test "$t"
  local d; d=$(new_project "modules-basic")
  (cd "$d" && "$INIT" --tool=opencode --modules=architecture-catalog,decision-memory --audit-level=standard >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/docs/architecture-options.md"
  assert_file "$t" "$d/harness/decisions/_template.md"
  assert_grep "$t" '"architecture-catalog"' "$d/harness/feature_list.json"
  assert_grep "$t" '"decision-memory"' "$d/harness/feature_list.json"
  assert_grep "$t" '"audit_level": "standard"' "$d/harness/feature_list.json"
}

test_default_install_no_modules() {
  local t="default install records empty modules and basic audit level"
  run_test "$t"
  local d; d=$(new_project "default-nomod")
  (cd "$d" && "$INIT" --tool=opencode >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_grep "$t" '"modules": \[\]' "$d/harness/feature_list.json"
  assert_grep "$t" '"audit_level": "basic"' "$d/harness/feature_list.json"
  assert_no_dir "$t" "$d/harness/tools"
  assert_no_file "$t" "$d/harness/baselines.json"
  assert_no_file "$t" "$d/harness/wekan.json"
  assert_no_dir "$t" "$d/harness/decisions"
  assert_no_file "$t" "$d/docs/architecture-options.md"
  assert_no_file "$t" "$d/docs/iteration-protocol.md"
}

test_invalid_module_rejected() {
  local t="--modules with an unknown name is rejected"
  run_test "$t"
  local d; d=$(new_project "invalid-module")
  if (cd "$d" && "$INIT" --tool=claude --modules=nope >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: should exit non-zero")
    echo "    FAIL: init.sh accepted --modules=nope"
  else
    PASS=$((PASS + 1))
  fi
}

test_invalid_audit_level_rejected() {
  local t="invalid --audit-level value is rejected"
  run_test "$t"
  local d; d=$(new_project "invalid-audit")
  if (cd "$d" && "$INIT" --tool=claude --audit-level=paranoid >/dev/null 2>&1); then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: should exit non-zero")
    echo "    FAIL: init.sh accepted --audit-level=paranoid"
  else
    PASS=$((PASS + 1))
  fi
}
```

Call them in Main after `test_module_manifests_valid`:

```bash
test_modules_install
test_default_install_no_modules
test_invalid_module_rejected
test_invalid_audit_level_rejected
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bash tests/test-install.sh 2>&1 | tail -6`
Expected: `FAIL: 3` — `--modules` installs exit non-zero (unknown argument), so `test_modules_install` fails once (returns early) and `test_default_install_no_modules` fails twice (missing `modules`/`audit_level` keys). The two rejection tests pass already (unknown argument → non-zero exit).

- [ ] **Step 4: Update the feature_list template**

`templates/feature_list.json` becomes exactly:

```json
{
  "project": {
    "name": "{{PROJECT_NAME}}",
    "parallel": false,
    "modules": [{{MODULES}}],
    "audit_level": "{{AUDIT_LEVEL}}"
  },
  "features": []
}
```

- [ ] **Step 5: Extend flag parsing in init.sh**

Update the usage comment (line 4) to:

```
# Usage: cd /path/to/your/project && /path/to/harness-standard/init.sh [--tool=claude|opencode] [--modules=m1,m2] [--audit-level=basic|standard|strict] [--force]
```

Replace the argument loop (current lines 44-56) with:

```bash
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
```

- [ ] **Step 6: Add manifest helpers and module selection**

Insert immediately **after** `info "Detected stack: $STACK"` (stack filtering needs `$STACK`), **before** the `case "$STACK"` command table:

```bash
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
fi
# (the interactive module menu is added by a later task)

AUDIT_LEVEL="${AUDIT_LEVEL:-basic}"
```

Note on ordering: this block must run after stack detection and before the copy phase.

- [ ] **Step 7: Add injection functions**

Insert before the `# ── Copy templates ──` section:

```bash
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
```

- [ ] **Step 8: Wire injection and feature_list keys**

Update the `harness/feature_list.json` creation block to:

```bash
if [ ! -f "harness/feature_list.json" ]; then
  MODULES_JSON=""
  if [ "${#MODULES_SELECTED[@]}" -gt 0 ]; then
    for m in "${MODULES_SELECTED[@]}"; do
      MODULES_JSON="${MODULES_JSON:+$MODULES_JSON, }\"$m\""
    done
  fi
  sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
      -e "s|{{MODULES}}|$MODULES_JSON|g" \
      -e "s|{{AUDIT_LEVEL}}|$AUDIT_LEVEL|g" \
      "$TEMPLATES_DIR/feature_list.json" > harness/feature_list.json
else
  ok "Keeping existing harness/feature_list.json"
fi
```

After `ok "Templates installed"` and before `# ── Validation ──`, add:

```bash
# ── Inject optional modules ────────────────────────────
if [ "${#MODULES_SELECTED[@]}" -gt 0 ]; then
  info "Injecting modules..."
  for m in "${MODULES_SELECTED[@]}"; do
    inject_module "$m"
  done
  info "Modules installed: ${MODULES_SELECTED[*]}"
fi
if [ "$AUDIT_LEVEL" != "basic" ]; then
  info "Audit level: $AUDIT_LEVEL"
fi
```

(Default stdout stays byte-identical — the module/audit info lines only print when non-default, per Global Constraints.)

At the end of the validation section (after `check_dir "harness/specs"`), add per-module verification (§4.2 "Validation gains a per-module check from each manifest's verify list"):

```bash
for m in "${MODULES_SELECTED[@]:+${MODULES_SELECTED[@]}}"; do
  while IFS= read -r vpath; do
    if [ -z "$vpath" ]; then continue; fi
    check_file "$vpath"
  done < <(manifest_list "$TEMPLATES_DIR/modules/$m/manifest.json" "verify")
done
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `FAIL: 0` (all previous tests plus the new ones; exact PASS count may be ~130).

- [ ] **Step 10: Commit**

```bash
git add init.sh templates/feature_list.json tests/test-install.sh
git commit -m "feat: module manifests, injection modes, --modules and --audit-level flags"
```

---

### Task 5: project-scanner module

Migrates annex D as `scan.py` with the §6.2 D.3/D.4 fixes (single parse pass, module-name resolution via suffix index, dict indexes instead of linear scans) and the D.5 protocol as its CLI. Python-stack only (`stacks: ["python"]`) — this module drives the stack-filter test (spec §8.5).

**Files:**
- Create: `templates/modules/project-scanner/manifest.json`
- Create: `templates/modules/project-scanner/scan.py` (executable)
- Test: `tests/test-install.sh` (2 new test functions)

**Interfaces:**
- Produces: `python3 harness/tools/scan.py [--summary|--impact FILE|--duplicates|--style [N]]` — used by Task 11 leader instructions and §4.5.

- [ ] **Step 1: Write the failing tests**

```bash
test_module_filtered_by_stack() {
  local t="stack-incompatible module is skipped with a warning"
  run_test "$t"
  local d; d=$(new_project "stack-filter")
  local out
  out="$(cd "$d" && "$INIT" --tool=claude --modules=project-scanner 2>&1)" || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  printf '%s\n' "$out" > "$d/init-output.txt"
  assert_grep "$t" "does not support stack" "$d/init-output.txt"
  assert_no_file "$t" "$d/harness/tools/scan.py"
  if grep -q '"project-scanner"' "$d/harness/feature_list.json"; then
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: skipped module recorded in feature_list.json")
    echo "    FAIL: skipped module recorded in feature_list.json"
  else
    PASS=$((PASS + 1))
  fi
}

test_project_scanner_module() {
  local t="project-scanner installs on python stack and scan.py answers queries"
  run_test "$t"
  local d; d=$(new_project "scanner")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=opencode --modules=project-scanner >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/harness/tools/scan.py"
  # Fixture project code
  mkdir -p "$d/core"
  cat > "$d/core/models.py" <<'EOF'
"""Domain models."""


class Order:
    """An order aggregate."""


def create_order():
    return Order()
EOF
  cat > "$d/core/service.py" <<'EOF'
"""Service layer."""
from core.models import Order


class OrderService:
    pass
EOF
  (cd "$d" && python3 harness/tools/scan.py --summary > summary.txt) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: scan.py --summary failed"); return
  }
  PASS=$((PASS + 1))
  assert_grep "$t" "core/models.py" "$d/summary.txt"
  assert_grep "$t" "core/service.py" "$d/summary.txt"
  (cd "$d" && python3 harness/tools/scan.py --impact core/service.py > impact.txt) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: scan.py --impact failed"); return
  }
  PASS=$((PASS + 1))
  # service.py depends on models.py — proves module-name resolution works
  assert_grep "$t" "core/models.py" "$d/impact.txt"
  if (cd "$d" && python3 harness/tools/scan.py --duplicates > dupes.txt); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: scan.py --duplicates failed")
    echo "    FAIL: scan.py --duplicates exited non-zero"
  fi
}
```

Call in Main after `test_invalid_audit_level_rejected`:

```bash
test_module_filtered_by_stack
test_project_scanner_module
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 2` (unknown module `project-scanner`).

- [ ] **Step 3: Create the manifest**

`templates/modules/project-scanner/manifest.json`:

```json
{
  "name": "project-scanner",
  "description": "Deterministic Python project scanner for impact analysis",
  "stacks": ["python"],
  "injects": [
    { "src": "scan.py", "dst": "harness/tools/scan.py", "mode": "copy" }
  ],
  "verify": ["harness/tools/scan.py"]
}
```

- [ ] **Step 4: Create scan.py**

`templates/modules/project-scanner/scan.py` (chmod +x):

```python
#!/usr/bin/env python3
"""Deterministic project scanner (harness project-scanner module).

v1 scope: Python AST analysis plus a generic file-count fallback.
The project is parsed exactly once; all queries are answered from indexes.

Usage (from the project root):
  python3 harness/tools/scan.py --summary          Project overview (default)
  python3 harness/tools/scan.py --impact FILE      Impact analysis for one file
  python3 harness/tools/scan.py --duplicates       Symbols defined in 2+ modules
  python3 harness/tools/scan.py --style [N]        Style sample of N files (default 3)
  python3 harness/tools/scan.py --root DIR         Scan a different root

Exit codes: 0 ok, 2 usage error.
"""

from __future__ import annotations

import ast
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

EXCLUDED_DIRS = {
    ".git", ".hg", ".svn", ".venv", "venv", "env", "__pycache__",
    "node_modules", ".tox", ".mypy_cache", ".pytest_cache",
    "build", "dist", ".harness",
}
REGION_RE = re.compile(r"#\s*region\s+(.+)")


@dataclass
class SourceFile:
    path: Path  # relative to the project root
    module: str  # dotted module name, e.g. "core.models"
    imports: list[str] = field(default_factory=list)
    classes: list[str] = field(default_factory=list)
    functions: list[str] = field(default_factory=list)
    docstring: str | None = None
    entry_point: bool = False
    regions: list[str] = field(default_factory=list)
    dependencies: set[str] = field(default_factory=set)  # resolved relative paths


class Scanner:
    """Parses every Python file once, then serves queries from dict indexes."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.files: list[SourceFile] = []
        self._by_module: dict[str, SourceFile] = {}
        self._by_class: dict[str, list[SourceFile]] = {}
        self._dependents: dict[str, set[str]] = {}

    def scan(self) -> None:
        for p in self.root.rglob("*.py"):
            if set(p.parts) & EXCLUDED_DIRS:
                continue
            sf = self._parse(p)
            if sf is not None:
                self.files.append(sf)
        self._build_indexes()

    def _parse(self, path: Path) -> SourceFile | None:
        rel = path.relative_to(self.root)
        try:
            text = path.read_text(encoding="utf-8")
            tree = ast.parse(text)
        except (SyntaxError, OSError, UnicodeDecodeError, ValueError):
            return None  # unreadable files are skipped, never fatal
        sf = SourceFile(path=rel, module=self._module_name(rel))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                sf.imports.extend(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                sf.imports.append(node.module)
            elif isinstance(node, ast.ClassDef):
                sf.classes.append(node.name)
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                sf.functions.append(node.name)
        sf.docstring = ast.get_docstring(tree)
        sf.entry_point = "__main__" in text
        sf.regions = [m.group(1).strip() for m in REGION_RE.finditer(text)]
        return sf

    @staticmethod
    def _module_name(rel: Path) -> str:
        parts = list(rel.with_suffix("").parts)
        if parts and parts[-1] == "__init__":
            parts = parts[:-1]
        return ".".join(parts)

    def _build_indexes(self) -> None:
        # Index every dotted suffix of each module name; the longest key wins.
        # "src/core/models.py" registers "src.core.models", "core.models", "models".
        for sf in self.files:
            parts = sf.module.split(".") if sf.module else []
            for i in range(len(parts)):
                key = ".".join(parts[i:])
                current = self._by_module.get(key)
                if current is None or len(parts) > len(current.module.split(".")):
                    self._by_module[key] = sf
        for sf in self.files:
            for name in sf.classes:
                self._by_class.setdefault(name, []).append(sf)
        # Reverse-dependency index, built once — never per query.
        for sf in self.files:
            for imp in sf.imports:
                target = self._resolve(imp)
                if target is not None and target.path != sf.path:
                    sf.dependencies.add(str(target.path))
                    self._dependents.setdefault(str(target.path), set()).add(str(sf.path))

    def _resolve(self, module: str) -> SourceFile | None:
        # Longest registered suffix match: "core.models" beats "models".
        parts = module.split(".")
        for i in range(len(parts)):
            key = ".".join(parts[i:])
            if key in self._by_module:
                return self._by_module[key]
        return None

    def affected_by(self, rel_path: str) -> set[str]:
        return set(self._dependents.get(rel_path, set()))

    def find_duplicates(self) -> dict[str, list[str]]:
        seen: dict[str, list[str]] = {}
        for sf in self.files:
            for name in sf.classes + sf.functions:
                seen.setdefault(name, []).append(str(sf.path))
        dupes: dict[str, list[str]] = {}
        for name, paths in seen.items():
            unique = sorted(set(paths))
            if len(unique) > 1:
                dupes[name] = unique
        return dupes

    def risk(self, sf: SourceFile) -> str:
        score = 0
        if self._dependents.get(str(sf.path)):
            score += 2
        if sf.classes:
            score += 1
        if sf.entry_point:
            score += 1
        if not sf.docstring:
            score += 1
        if score >= 4:
            return "HIGH"
        if score >= 2:
            return "MEDIUM"
        return "LOW"


def cmd_summary(sc: Scanner) -> str:
    files = sc.files
    if not files:
        return generic_summary(sc.root)
    test_files = [f for f in files if "test" in f.path.name or "test" in f.path.parent.name]
    entry_points = [f for f in files if f.entry_point]
    missing_docs = [f for f in files if f.classes and not f.docstring]
    edges = sum(len(f.dependencies) for f in files)
    high = [f for f in files if sc.risk(f) == "HIGH"]
    packages = sorted({str(f.path.parent) for f in files})
    dupes = sc.find_duplicates()
    return "\n".join([
        "## Project Reading Summary",
        f"- Total Python files: {len(files)}",
        f"- Test files: {len(test_files)}",
        f"- Packages: {len(packages)}",
        f"- Import graph edges: {edges}",
        "- Entry points: " + (", ".join(str(f.path) for f in entry_points) or "none"),
        f"- Files with classes and no docstring: {len(missing_docs)}",
        "- HIGH-risk files: " + (", ".join(str(f.path) for f in high) or "none"),
        "- Duplicated symbols: " + (", ".join(sorted(dupes)) or "none"),
    ])


def generic_summary(root: Path) -> str:
    counts: dict[str, int] = {}
    for p in root.rglob("*"):
        if p.is_file() and not (set(p.parts) & EXCLUDED_DIRS):
            key = p.suffix or "(no extension)"
            counts[key] = counts.get(key, 0) + 1
    lines = ["## Project Reading Summary (generic fallback - no Python files)"]
    for ext, n in sorted(counts.items(), key=lambda kv: -kv[1])[:10]:
        lines.append(f"- {ext}: {n} files")
    if len(lines) == 1:
        lines.append("- (empty project)")
    return "\n".join(lines)


def cmd_impact(sc: Scanner, target: str) -> str:
    path = Path(target)
    sf = next((f for f in sc.files if f.path == path), None)
    if sf is None and path.is_absolute():
        try:
            rel = path.resolve().relative_to(sc.root.resolve())
        except ValueError:
            rel = None
        if rel is not None:
            sf = next((f for f in sc.files if f.path == rel), None)
    if sf is None:
        return f"error: file not found in project: {target}"
    dependents = sorted(sc.affected_by(str(sf.path)))
    tests = [d for d in dependents if "test" in d]
    return "\n".join([
        f"## Impact analysis - {sf.path}",
        "- Dependencies: " + (", ".join(sorted(sf.dependencies)) or "none"),
        "- Dependents: " + (", ".join(dependents) or "none"),
        "- Tests affected: " + (", ".join(tests) or "none"),
        "- Impact level: " + ("HIGH" if dependents else "MEDIUM"),
        f"- Change risk: {sc.risk(sf)}",
    ])


def cmd_duplicates(sc: Scanner) -> str:
    dupes = sc.find_duplicates()
    if not dupes:
        return "## Duplicates\n- none"
    lines = ["## Duplicates"]
    for name in sorted(dupes):
        lines.append(f"- {name}: {', '.join(dupes[name])}")
    return "\n".join(lines)


def cmd_style(sc: Scanner, n: int) -> str:
    sample = [f for f in sc.files if "test" not in f.path.name][:n]
    lines = ["## Style sample"]
    for sf in sample:
        lines.append(
            f"- {sf.path}: classes={sf.classes or '-'}"
            f" regions={sf.regions or '-'}"
            f" first_imports={sf.imports[:3] or '-'}"
        )
    if not sample:
        lines.append("- (no Python files found)")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    root = Path.cwd()
    style_n = 3
    command: str | None = None
    target: str | None = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--summary", "--duplicates"):
            command = a
        elif a == "--impact":
            command = a
            i += 1
            if i >= len(argv):
                print("error: --impact requires a file path", file=sys.stderr)
                return 2
            target = argv[i]
        elif a == "--style":
            command = a
            if i + 1 < len(argv) and argv[i + 1].isdigit():
                i += 1
                style_n = int(argv[i])
        elif a == "--root":
            i += 1
            if i >= len(argv):
                print("error: --root requires a path", file=sys.stderr)
                return 2
            root = Path(argv[i])
        else:
            print(f"error: unknown argument: {a}", file=sys.stderr)
            return 2
        i += 1
    if command is None:
        command = "--summary"
    sc = Scanner(root)
    sc.scan()
    if command == "--summary":
        print(cmd_summary(sc))
    elif command == "--impact":
        print(cmd_impact(sc, target or ""))
    elif command == "--duplicates":
        print(cmd_duplicates(sc))
    elif command == "--style":
        print(cmd_style(sc, style_n))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `FAIL: 0`.

- [ ] **Step 6: Commit**

```bash
git add templates/modules tests/test-install.sh
git commit -m "feat: project-scanner module with fixed deterministic scan.py"
```

---

### Task 6: security-audit module + C7 checkpoint

Migrates annex B with the §6.2 corrections (OWASP A01-A05 mapping, modern headers without deprecated `X-XSS-Protection`, B.3 unrealistic rate-limit test removed) into a checklist appended to `docs/verification.md`, plus a degrading SAST wrapper per the §6.3 tool table. Also adds the installer-side C7 checkpoint injection (§4.4).

**Files:**
- Create: `templates/modules/security-audit/manifest.json`
- Create: `templates/modules/security-audit/verification-audit.md`
- Create: `templates/modules/security-audit/audit-security.sh` (executable)
- Create: `templates/modules/_shared/c7-audit.md`
- Modify: `init.sh` (C7 injection after the module injection loop)
- Test: `tests/test-install.sh` (1 new test function)

**Interfaces:**
- Consumes: `inject_append_section` (Task 4).
- Produces: `harness/tools/audit-security.sh` exit contract — 0 = no HIGH findings (or checklist-only), 1 = HIGH findings, 2 = usage error — used by Task 11 reviewer instructions; `docs/verification.md` section "Security Audit Checklist" applied manually at `audit_level: basic`.

- [ ] **Step 1: Write the failing test**

```bash
test_security_audit_module() {
  local t="security-audit installs checklist, tool, C7; script degrades without tools"
  run_test "$t"
  local d; d=$(new_project "sec-audit")
  (cd "$d" && "$INIT" --tool=claude --modules=security-audit --audit-level=standard >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_executable "$t" "$d/harness/tools/audit-security.sh"
  assert_count "$t" "harness:module:security-audit:start" "$d/docs/verification.md" 1
  assert_grep "$t" "Security Audit Checklist" "$d/docs/verification.md"
  assert_grep "$t" "C7 — Audit" "$d/harness/CHECKPOINTS.md"
  assert_count "$t" "harness:module:audit-checkpoint:start" "$d/harness/CHECKPOINTS.md" 1
  # Generic project without tools: the script degrades to checklist-only, exit 0
  if (cd "$d" && bash harness/tools/audit-security.sh > audit-report.txt 2>&1); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: audit-security.sh non-zero on tool-less project")
    echo "    FAIL: audit-security.sh should degrade to checklist-only with exit 0"
  fi
  assert_grep "$t" "Checklist" "$d/audit-report.txt"
}
```

Call in Main after `test_project_scanner_module`:

```bash
test_security_audit_module
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 1` (unknown module `security-audit`).

- [ ] **Step 3: Create the manifest**

`templates/modules/security-audit/manifest.json`:

```json
{
  "name": "security-audit",
  "description": "Security audit checklist plus SAST and dependency scan tool",
  "stacks": ["typescript", "node", "android", "java", "python", "rust", "generic"],
  "injects": [
    { "src": "verification-audit.md", "dst": "docs/verification.md", "mode": "append-section" },
    { "src": "audit-security.sh", "dst": "harness/tools/audit-security.sh", "mode": "copy" }
  ],
  "verify": ["harness/tools/audit-security.sh"]
}
```

- [ ] **Step 4: Create the checklist content**

`templates/modules/security-audit/verification-audit.md`:

````markdown
## Security Audit Checklist (security-audit module)

> Appended by the harness `security-audit` module. The reviewer applies this
> checklist manually at `audit_level: basic`, and runs
> `bash harness/tools/audit-security.sh` at `standard` and above. Findings are
> recorded in the feature's progress entry with severity (HIGH/MEDIUM/LOW),
> description, and resolution or explicit waiver.

### A01 Broken Access Control
- [ ] Sensitive endpoints and operations require authentication.
- [ ] Role/permission checks enforced server-side, not only in the UI.

### A02 Cryptographic Failures
- [ ] No hardcoded secrets; credentials come from environment or a secrets manager.
- [ ] Cryptographic randomness from the stack's secure source (`secrets`, `crypto`).
- [ ] Sensitive data encrypted at rest and in transit where required.

### A03 Injection
- [ ] SQL via parameterized queries only — never string concatenation.
- [ ] No `shell=True` or unsanitized shell interpolation; file paths validated against traversal.
- [ ] HTML/JSON output escaped (XSS) when data reaches a UI.

### A04 Insecure Design
- [ ] External input validated (type, range, format, length) at the boundary.
- [ ] Rate limiting and retry-with-backoff considered for public endpoints.

### A05 Security Misconfiguration
- [ ] No debug mode, verbose stack traces, or default credentials in production config.
- [ ] Error messages generic externally; internal detail logged securely, without PII.

### API security headers (when serving HTTP)

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
Permissions-Policy: <deny unused browser capabilities>
Referrer-Policy: no-referrer
Cache-Control: no-store          # only for sensitive responses
```

(Deprecated `X-XSS-Protection` is intentionally not listed.)

### Automated scanning (audit_level standard and above)

Run `bash harness/tools/audit-security.sh` from the project root. The script uses
the stack's tools when installed and degrades to this checklist otherwise — it
must never be a blocker by itself; HIGH findings it reports reject the approval.

### Report format (in the review file)

```markdown
## Security Audit
- Method: manual checklist | audit-security.sh
- Findings:
  - [HIGH/MEDIUM/LOW] <description> — <resolution or waiver>
- Result: PASS | REJECTED (HIGH findings unresolved)
```
````

- [ ] **Step 5: Create the C7 checkpoint source**

`templates/modules/_shared/c7-audit.md` (the `_shared` directory has no manifest.json, so the module discovery loop never lists it as a selectable module):

````markdown
## C7 — Audit (conditional)

- [ ] The latest progress entry contains the audit report (`audit_level` standard/strict) or the manual security-checklist confirmation (`basic`).
- [ ] Findings above the configured audit level's threshold are resolved or explicitly waived in the progress entry.
````

- [ ] **Step 6: Create audit-security.sh**

`templates/modules/security-audit/audit-security.sh` (chmod +x):

```bash
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
```

- [ ] **Step 7: Add the C7 injection to init.sh**

In the `# ── Inject optional modules ──` block (Task 4), extend the loop with the C7 guard:

```bash
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
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `FAIL: 0`.

- [ ] **Step 9: Commit**

```bash
git add templates/modules init.sh tests/test-install.sh
git commit -m "feat: security-audit module with SAST wrapper and C7 checkpoint"
```

---

### Task 7: performance-benchmarks module + strict-install test

Migrates annex A with the §6.2 corrections (pytest-benchmark / stack frameworks instead of the hand-rolled `BenchmarkRunner`, compact report, thresholds in `baselines.json`). Delivers the full spec §8.1 strict-install test.

**Files:**
- Create: `templates/modules/performance-benchmarks/manifest.json`
- Create: `templates/modules/performance-benchmarks/verification-benchmarks.md`
- Create: `templates/modules/performance-benchmarks/bench.sh` (executable)
- Create: `templates/modules/performance-benchmarks/baselines.json`
- Test: `tests/test-install.sh` (1 new test function)

**Interfaces:**
- Consumes: `inject_append_section` (Task 4), `_shared/c7-audit.md` (Task 6).
- Produces: `harness/tools/bench.sh` exit contract — 0 = ok / record-only, 1 = regression beyond critical threshold, 2 = usage — used by Task 11 reviewer instructions; `harness/baselines.json` (user state, preserved under `--force`).

- [ ] **Step 1: Write the failing test (spec §8.1)**

```bash
test_modules_install_strict() {
  local t="strict install injects audit modules exactly once, C7, and feature_list entries"
  run_test "$t"
  local d; d=$(new_project "modules-strict")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=opencode --modules=security-audit,performance-benchmarks --audit-level=strict >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_executable "$t" "$d/harness/tools/audit-security.sh"
  assert_executable "$t" "$d/harness/tools/bench.sh"
  assert_file "$t" "$d/harness/baselines.json"
  assert_count "$t" "harness:module:security-audit:start" "$d/docs/verification.md" 1
  assert_count "$t" "harness:module:performance-benchmarks:start" "$d/docs/verification.md" 1
  assert_grep "$t" "C7 — Audit" "$d/harness/CHECKPOINTS.md"
  assert_grep "$t" '"security-audit"' "$d/harness/feature_list.json"
  assert_grep "$t" '"performance-benchmarks"' "$d/harness/feature_list.json"
  assert_grep "$t" '"audit_level": "strict"' "$d/harness/feature_list.json"
}
```

Call in Main after `test_security_audit_module`:

```bash
test_modules_install_strict
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 1` (unknown module `performance-benchmarks`).

- [ ] **Step 3: Create the manifest**

`templates/modules/performance-benchmarks/manifest.json`:

```json
{
  "name": "performance-benchmarks",
  "description": "Benchmark verification rules and a stack-aware bench runner",
  "stacks": ["typescript", "node", "android", "java", "python", "rust", "generic"],
  "injects": [
    { "src": "verification-benchmarks.md", "dst": "docs/verification.md", "mode": "append-section" },
    { "src": "bench.sh", "dst": "harness/tools/bench.sh", "mode": "copy" },
    { "src": "baselines.json", "dst": "harness/baselines.json", "mode": "copy-if-missing" }
  ],
  "verify": ["harness/tools/bench.sh"]
}
```

- [ ] **Step 4: Create the verification content**

`templates/modules/performance-benchmarks/verification-benchmarks.md`:

````markdown
## Performance Benchmarks (performance-benchmarks module)

> Appended by the harness `performance-benchmarks` module. Benchmarks are run by
> the reviewer with `bash harness/tools/bench.sh` at `audit_level: strict`. They
> are required when a feature: processes > 1,000 items, involves I/O operations
> (DB, API, file), has concurrency/parallelism concerns, or uses caching or
> memoization.

### Framework per stack

| Stack | Tool | When unavailable |
|---|---|---|
| python | `pytest-benchmark` (mark tests with `@pytest.mark.benchmark`) | `bench.sh` reports record-only |
| typescript / node | `vitest bench` (if configured) | record-only |
| rust | `cargo bench` (if `benches/` configured) | record-only |
| java / android | checklist-only (measure manually if needed) | checklist-only |
| generic | checklist-only | checklist-only |

### Baselines (`harness/baselines.json`)

Starts empty (`{}`). After the first measurement of a function/test, add an entry:

```json
{
  "test_send_email_throughput": {
    "mean_ms": 42.3,
    "thresholds": {
      "mean_ms": { "warning": 1.5, "critical": 2.0 }
    }
  }
}
```

- `mean_ms` is the reference measurement (milliseconds; `mean * 1000` from
  pytest-benchmark).
- Multipliers: exceeding `warning` logs a warning; exceeding `critical` rejects
  approval at `strict`.

### Report (compact — only when benchmarks were required)

```markdown
## Performance Benchmarks
- Scenario: <what was measured>
- Result: <mean/p95 or framework output excerpt>
- vs baseline: ok (<ratio>x) | warning | REGRESSION
```

Without a baseline, `bench.sh` records values and warns; it never blocks.

A transient `harness/.bench-last.json` may be produced by the benchmark run;
delete it before closing the session (it is not user state).
````

- [ ] **Step 5: Create baselines.json**

`templates/modules/performance-benchmarks/baselines.json` (exactly):

```json
{}
```

- [ ] **Step 6: Create bench.sh**

`templates/modules/performance-benchmarks/bench.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# bench.sh — run stack benchmarks and compare against harness/baselines.json.
#
# Run by the reviewer at audit_level: strict. The installer never runs this
# script. Without a baseline the script records values and warns (never blocks).
#
# Usage: bash harness/tools/bench.sh
# Exit codes: 0 = ok or record-only, 1 = regression beyond critical threshold, 2 = usage error

set -uo pipefail

BASELINES="harness/baselines.json"
MEASURED=0
REJECT=0
OUT="$(mktemp)"
trap 'rm -f "$OUT" harness/.bench-last.json' EXIT

STACK=""
if [ -f "tsconfig.json" ]; then STACK="typescript"
elif [ -f "package.json" ]; then STACK="node"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then STACK="python"
elif [ -f "Cargo.toml" ]; then STACK="rust"
else STACK="generic"
fi

echo "# Benchmark Report (stack: $STACK)"
echo ""

case "$STACK" in
  python)
    if python3 -c "import pytest_benchmark" >/dev/null 2>&1; then
      echo "## Runner: pytest-benchmark"
      if python3 -m pytest -q tests --benchmark-only --benchmark-json=harness/.bench-last.json > "$OUT" 2>&1; then
        tail -n 15 "$OUT"
        MEASURED=1
      else
        echo "pytest --benchmark-only failed (no benchmark-marked tests?)"
        cat "$OUT"
      fi
    else
      echo "## Runner: pytest-benchmark — SKIPPED (not installed; pip install pytest-benchmark)"
      echo "Record-only: no measurements taken."
    fi
    ;;
  typescript|node)
    if [ -d "node_modules/vitest" ] && npx vitest bench --run > "$OUT" 2>&1; then
      echo "## Runner: vitest bench"
      tail -n 15 "$OUT"
      MEASURED=1
    else
      echo "## Runner: vitest bench — SKIPPED (not configured). Record-only."
    fi
    ;;
  rust)
    if { [ -d "benches" ] || grep -q "\[\[bench\]\]" Cargo.toml 2>/dev/null; } && cargo bench > "$OUT" 2>&1; then
      echo "## Runner: cargo bench"
      tail -n 15 "$OUT"
      MEASURED=1
    else
      echo "## Runner: cargo bench — SKIPPED (no benches configured). Record-only."
    fi
    ;;
  *)
    echo "## Checklist-only (no automated benchmarks for stack: $STACK)"
    ;;
esac

# Compare against baselines when we have measurements, a non-empty baseline
# file, and python3 available (only the python runner produces parseable JSON).
if [ "$MEASURED" -eq 1 ] && [ "$STACK" = "python" ] \
   && [ -s "$BASELINES" ] \
   && [ "$(cat "$BASELINES")" != "{}" ] \
   && command -v python3 >/dev/null 2>&1 \
   && [ -f "harness/.bench-last.json" ]; then
  echo ""
  echo "## Baseline comparison"
  if ! python3 - "$BASELINES" "harness/.bench-last.json" <<'PYEOF'; then
import json, sys
base = json.load(open(sys.argv[1]))
data = json.load(open(sys.argv[2]))
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
        reject = True
    elif ratio > warn_m:
        print(f"- {name}: WARNING {ratio:.2f}x vs baseline {ref:.1f} ms")
    else:
        print(f"- {name}: ok {mean_ms:.1f} ms ({ratio:.2f}x baseline)")
sys.exit(1 if reject else 0)
PYEOF
    REJECT=1
  fi
elif [ "$MEASURED" -eq 1 ]; then
  echo ""
  echo "No usable baseline in $BASELINES — values recorded only (add entries after review)."
fi

echo ""
if [ "$REJECT" -eq 1 ]; then
  echo "VERDICT: benchmark regression beyond critical threshold — approval rejected (strict)."
  exit 1
fi
echo "VERDICT: no benchmark regression."
exit 0
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `FAIL: 0`.

- [ ] **Step 8: Commit**

```bash
git add templates/modules tests/test-install.sh
git commit -m "feat: performance-benchmarks module with stack-aware bench runner"
```

---

### Task 8: `--force` with modules — section replacement + metadata refresh (spec §8.4)

Two behaviors under `--force`: injected sections are replaced without duplication, and the `modules`/`audit_level` metadata in the existing `harness/feature_list.json` is refreshed to match the current run's selection (best-effort; known limitations at the end of this plan).

**Files:**
- Modify: `init.sh` (feature_list else-branch: `refresh_project_metadata`)
- Test: `tests/test-install.sh` (2 new test functions)

**Interfaces:**
- Consumes: marker-scoped section replacement; `copy-if-missing` preservation of `harness/baselines.json` and `harness/decisions/` (Task 4); `MODULES_JSON` / `AUDIT_LEVEL` variables.
- Produces: `refresh_project_metadata <feature-list>` — after a `--force`, `feature_list.json` metadata reflects what THIS run installed.

- [ ] **Step 1: Write the failing tests**

```bash
test_force_modules_replace_sections() {
  local t="--force with modules replaces injected sections and preserves user state"
  run_test "$t"
  local d; d=$(new_project "force-modules")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=claude --modules=security-audit,performance-benchmarks --audit-level=standard >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: first install failed"); return
  }
  PASS=$((PASS + 1))
  # simulate user state created after install
  echo '{"my_func": {"mean_ms": 12.5}}' > "$d/harness/baselines.json"
  mkdir -p "$d/harness/decisions"
  echo "# ADR-001" > "$d/harness/decisions/adr-001.md"
  (cd "$d" && "$INIT" --force --tool=claude --modules=security-audit,performance-benchmarks --audit-level=standard >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: force install failed"); return
  }
  PASS=$((PASS + 1))
  # sections replaced, not duplicated
  assert_count "$t" "harness:module:security-audit:start" "$d/docs/verification.md" 1
  assert_count "$t" "harness:module:performance-benchmarks:start" "$d/docs/verification.md" 1
  assert_count "$t" "harness:module:audit-checkpoint:start" "$d/harness/CHECKPOINTS.md" 1
  # user state preserved
  assert_grep "$t" '"my_func"' "$d/harness/baselines.json"
  assert_file "$t" "$d/harness/decisions/adr-001.md"
}

test_force_switch_modules_metadata() {
  local t="--force with a different module set refreshes feature_list metadata"
  run_test "$t"
  local d; d=$(new_project "force-switch-mods")
  touch "$d/requirements.txt"
  (cd "$d" && "$INIT" --tool=opencode --modules=security-audit,performance-benchmarks --audit-level=strict >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: first install failed"); return
  }
  PASS=$((PASS + 1))
  (cd "$d" && "$INIT" --force --tool=opencode --modules=architecture-catalog --audit-level=basic >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: force install failed"); return
  }
  PASS=$((PASS + 1))
  # metadata refreshed to the new selection
  assert_grep "$t" '"architecture-catalog"' "$d/harness/feature_list.json"
  assert_count "$t" '"performance-benchmarks"' "$d/harness/feature_list.json" 0
  assert_grep "$t" '"audit_level": "basic"' "$d/harness/feature_list.json"
  # unselected append-section content is gone (base files re-copied clean, not re-injected)
  assert_count "$t" "harness:module:security-audit:start" "$d/docs/verification.md" 0
  assert_count "$t" "harness:module:audit-checkpoint:start" "$d/harness/CHECKPOINTS.md" 0
}
```

Call both in Main after `test_modules_install_strict`:

```bash
test_force_modules_replace_sections
test_force_switch_modules_metadata
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 3` — the first test passes already (Task 4's injection is correct); the metadata test fails 3 times (`architecture-catalog` not recorded, `performance-benchmarks` still recorded, `audit_level` still `strict`). The two section-count-0 assertions pass (base re-copy already cleans them).

- [ ] **Step 3: Implement the metadata refresh in init.sh**

Add next to the injection functions (Task 4, Step 7 area):

```bash
refresh_project_metadata() {  # refresh_project_metadata <feature-list>
  # Best-effort: --force records the current run's module/audit selection.
  # The target lines have the exact shape the installer itself writes, so a
  # line-scoped sed is safe; any other shape only warns.
  local fl="$1"
  if grep -q '"modules"[[:space:]]*:' "$fl"; then
    sed -i "s|\"modules\"[[:space:]]*:[[:space:]]*\[[^]]*\]|\"modules\": [$MODULES_JSON]|" "$fl"
  else
    warn "Could not update 'modules' in $fl — set it manually in the project section."
  fi
  if grep -q '"audit_level"[[:space:]]*:' "$fl"; then
    sed -i "s|\"audit_level\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"audit_level\": \"$AUDIT_LEVEL\"|" "$fl"
  else
    warn "Could not update 'audit_level' in $fl — set it manually in the project section."
  fi
}
```

Restructure the feature_list block so `MODULES_JSON` is built before the branch, and call the refresh on the else branch:

```bash
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
```

Semantics note: a piped (non-interactive) `--force` resets metadata to the EOF defaults (`[]` / `basic`) — that reflects what that run actually injected. Role-template conditionals gate on file existence, so nothing misbehaves; only the recorded list changes. The existing `test_force_reinstall_preserves_state` (custom `{"custom": true}` feature_list) must stay green: no `modules`/`audit_level` lines → only warnings, file untouched.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add init.sh tests/test-install.sh
git commit -m "feat: --force refreshes modules/audit_level metadata in feature_list.json"
```

---

### Task 9: wekan-tickets module (tool-dependent dst)

Adapts the external `wekan-tasks` skill into a module (§4.7): homelab data removed, config in `harness/wekan.json`, lists named after SDD states, SKILL.md in English, role traces table. The skill destination depends on the chosen tool — this exercises the tool-keyed `dst` branch of `inject_module` written in Task 4.

**Files:**
- Create: `templates/modules/wekan-tickets/manifest.json`
- Create: `templates/modules/wekan-tickets/SKILL.md`
- Create: `templates/modules/wekan-tickets/wekan.json`
- Test: `tests/test-install.sh` (1 new test function)

**Interfaces:**
- Consumes: tool-keyed `dst` resolution in `inject_module` (Task 4).
- Produces: `.claude/skills/wekan-tasks/SKILL.md` **or** `.opencode/skill/wekan-tasks/SKILL.md` depending on `--tool`; `harness/wekan.json` (user state). Feature objects may carry `"wekan_card": "<id>"` (written by the leader; documented in SKILL.md).

- [ ] **Step 1: Write the failing test (spec §8.6)**

```bash
test_wekan_tickets_tool_dst() {
  local t="wekan-tickets installs the skill for the chosen tool and preserves config"
  run_test "$t"
  # claude variant
  local d; d=$(new_project "wekan-claude")
  (cd "$d" && "$INIT" --tool=claude --modules=wekan-tickets >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: claude install failed"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d/.claude/skills/wekan-tasks/SKILL.md"
  assert_no_file "$t" "$d/.opencode/skill/wekan-tasks/SKILL.md"
  assert_file "$t" "$d/harness/wekan.json"
  if python3 - "$d/harness/wekan.json" <<'PYEOF' >/dev/null 2>&1; then
import json, sys
raw = open(sys.argv[1]).read()
data = json.loads(raw)
for key in ("url", "list_map", "credentials_file", "enabled"):
    assert key in data, f"missing key: {key}"
assert "WEKAN_API_BEARER_TOKEN" not in raw, "secrets must not be in wekan.json"
assert "WEKAN_API_USER_ID" not in raw, "secrets must not be in wekan.json"
sys.exit(0)
PYEOF
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: wekan.json invalid or contains secrets")
    echo "    FAIL: wekan.json invalid or contains secrets"
  fi
  # preserved as user state under --force
  echo '{"custom": true}' > "$d/harness/wekan.json"
  (cd "$d" && "$INIT" --force --tool=claude --modules=wekan-tickets >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: force install failed"); return
  }
  PASS=$((PASS + 1))
  assert_grep "$t" '"custom": true' "$d/harness/wekan.json"
  assert_file "$t" "$d/.claude/skills/wekan-tasks/SKILL.md"
  # opencode variant
  local d2; d2=$(new_project "wekan-opencode")
  (cd "$d2" && "$INIT" --tool=opencode --modules=wekan-tickets >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: opencode install failed"); return
  }
  PASS=$((PASS + 1))
  assert_file "$t" "$d2/.opencode/skill/wekan-tasks/SKILL.md"
  assert_no_file "$t" "$d2/.claude/skills/wekan-tasks/SKILL.md"
}
```

Call in Main after `test_force_modules_replace_sections`:

```bash
test_wekan_tickets_tool_dst
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 1` (unknown module `wekan-tickets`).

- [ ] **Step 3: Create the manifest**

`templates/modules/wekan-tickets/manifest.json`:

```json
{
  "name": "wekan-tickets",
  "description": "Mirror every workflow state transition on a Wekan kanban board",
  "stacks": ["typescript", "node", "android", "java", "python", "rust", "generic"],
  "injects": [
    { "src": "SKILL.md", "dst": {"claude": ".claude/skills/wekan-tasks/SKILL.md", "opencode": ".opencode/skill/wekan-tasks/SKILL.md"}, "mode": "copy" },
    { "src": "wekan.json", "dst": "harness/wekan.json", "mode": "copy-if-missing" }
  ],
  "verify": ["harness/wekan.json"]
}
```

- [ ] **Step 4: Create the default config**

`templates/modules/wekan-tickets/wekan.json`:

```json
{
  "_readme": "Wekan ticket mirror config (no secrets here). board_name empty means: use the project name from harness/feature_list.json. credentials_file points to a gitignored env file that must define WEKAN_API_BEARER_TOKEN and WEKAN_API_USER_ID. enabled=false is a kill switch: agents skip all Wekan actions.",
  "url": "https://wekan.example.test",
  "board_name": "",
  "list_map": {
    "pending": "pending",
    "spec_ready": "spec_ready",
    "in_progress": "in_progress",
    "blocked": "blocked",
    "done": "done"
  },
  "credentials_file": ".harness-wekan.env",
  "enabled": true
}
```

- [ ] **Step 5: Create the SKILL.md**

`templates/modules/wekan-tickets/SKILL.md`:

````markdown
---
name: wekan-tasks
description: Mirror harness workflow states on the project's Wekan kanban board — create a feature card, move it between state lists, comment progress. Use whenever a harness feature changes state and the wekan-tickets module is installed (harness/wekan.json present).
---

# wekan-tasks — Wekan ticket mirror for the harness SDD flow

The harness is the source of truth (`harness/feature_list.json`); Wekan is the
**visible trace**. Every workflow state transition is mirrored on the board: the
card IS the ticket. Wekan sync must NEVER block the SDD flow — on any failure,
log it in `harness/progress/current.md` and continue.

## Configuration and secrets

All connection data lives in `harness/wekan.json`:

- `url` — base URL of the self-hosted Wekan instance.
- `board_name` — board title (empty = project name from `harness/feature_list.json`).
- `list_map` — SDD state → list title. Default lists: `pending`, `spec_ready`,
  `in_progress`, `blocked`, `done`. Card position == feature status.
- `credentials_file` — path to a **gitignored** env file that must define:

  ```
  WEKAN_API_BEARER_TOKEN=...
  WEKAN_API_USER_ID=...
  ```

- `enabled` — kill switch. If `false`, or if `harness/wekan.json` is absent, skip
  every Wekan action silently.

Read secrets via bash `sed`, never with file-read tools (`.env` files are usually
read-denied). The token may end with `=` — `cut -d= -f2` truncates it:

```bash
CFG_URL="$(sed -n 's/^"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' harness/wekan.json)"
CRED="$(sed -n 's/^"credentials_file"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' harness/wekan.json)"
TOK="$(sed -n 's/^WEKAN_API_BEARER_TOKEN=//p' "$CRED")"
USR="$(sed -n 's/^WEKAN_API_USER_ID=//p' "$CRED")"
AUTH=(-H "Authorization: Bearer $TOK" -H "X-User-Id: $USR")
# Self-signed certs → always: curl -sk
```

If the server is unreachable or credentials fail: log once in
`harness/progress/current.md`, stop syncing, keep working.

## Resolve the board (once per session)

1. **Board lookup:** `GET /api/boards` only lists PUBLIC boards. Try it first;
   if the board is private, fall back to a mongo lookup (only when mongo
   credentials are available in the credentials file or the operator provides
   them — never guess):

   ```bash
   curl -sk "${AUTH[@]}" "$CFG_URL/api/boards"   # public boards, [{_id,title},...]
   # fallback (needs mongo creds):
   docker exec wekan-mongo mongosh --quiet \
     "mongodb://$MUSR:$MPW@localhost:27017/test?authSource=admin" \
     --eval 'db.boards.findOne({title:"<project>"},{_id:1,title:1})'
   ```

2. **Create if missing** (idempotent; the creator becomes board admin) and ensure
   the five `list_map` lists exist:

   ```bash
   BOARD=$(curl -sk "${AUTH[@]}" -X POST "$CFG_URL/api/boards" \
     -H "Content-Type: application/json" -d '{"title":"<project>"}' \
     | python3 -c "import json,sys; print(json.load(sys.stdin)['_id'])")
   # POST returns {_id, defaultSwimlaneId}; keep the swimlane id
   SWIMLANE=$(curl -sk "${AUTH[@]}" "$CFG_URL/api/boards/$BOARD" | python3 -c "import json,sys; print(json.load(sys.stdin)['defaultSwimlaneId'])")
   for L in pending spec_ready in_progress blocked done; do
     curl -sk "${AUTH[@]}" -X POST "$CFG_URL/api/boards/$BOARD/lists" \
       -H "Content-Type: application/json" -d "{\"title\":\"$L\"}"
   done
   ```

3. **Resolve list ids** once and reuse them:

   ```bash
   curl -sk "${AUTH[@]}" "$CFG_URL/api/boards/$BOARD/lists"   # [{_id,title},...]
   ```

## Role traces (who does what, when)

| Event | Agent | Wekan action |
|---|---|---|
| Feature added / first seen at session start | leader | Create card (or reuse the card id from the feature's `"wekan_card"`); fill title + description (title, description, acceptance criteria) |
| Spec written | spec-author | Move card → `spec_ready`; comment with the spec path |
| Human approves spec | leader | Move card → `in_progress` |
| Implementation starts | implementer | Set `startAt` to today |
| Task progresses / blocked | implementer | Comment with progress; if blocked move → `blocked` (and back when unblocked) |
| Review verdict | reviewer | Comment with verdict; on approval move → `done` and set `endAt` to today |
| Rework requested | reviewer | Move card back → `in_progress`; comment with findings |

The leader records the created card id in the feature object:
`"wekan_card": "<cardId>"` in `harness/feature_list.json` — agents then never
re-search the board for the card.

## Operations

```bash
# Create a card — swimlaneId is REQUIRED (500 without it)
curl -sk "${AUTH[@]}" -X POST "$CFG_URL/api/boards/$BOARD/lists/$LIST_PENDING/cards" \
  -H "Content-Type: application/json" \
  -d '{"title":"<feature title>","description":"<desc + acceptance>","authorId":"'$USR'","swimlaneId":"'$SWIMLANE'"}'
# → {"_id":"<cardId>"}

# Move a card to another list (= state transition)
curl -sk "${AUTH[@]}" -X PUT "$CFG_URL/api/boards/$BOARD/lists/$OLD_LIST/cards/$CARD" \
  -H "Content-Type: application/json" -d '{"listId":"'$NEW_LIST'"}'

# Comment
curl -sk "${AUTH[@]}" -X POST "$CFG_URL/api/boards/$BOARD/cards/$CARD/comments" \
  -H "Content-Type: application/json" -d '{"comment":"spec_ready — see harness/specs/<name>/"}'

# Set startAt / endAt / dueAt (ISO 8601; date-only saves as T00:00:00Z)
curl -sk "${AUTH[@]}" -X PUT "$CFG_URL/api/boards/$BOARD/lists/$LIST/cards/$CARD" \
  -H "Content-Type: application/json" -d '{"startAt":"2026-09-07","endAt":"2026-09-08"}'
```

## Common errors

| Symptom | Cause and fix |
|---|---|
| 401/403 listing `/api/boards` | That route only returns PUBLIC boards; use the mongo fallback for private boards. |
| 401 Unauthorized | Token truncated (ends with `=`) or missing `X-User-Id`. Re-extract with `sed`; always send both headers. |
| 500 "Swimlane ID is required" | Add `swimlaneId` when creating the card. |
| 405 Method Not Allowed | Wrong route/method, or the token was cut. |
| Empty board lookup | Board does not exist yet → create it (see above). |

## Never do

- Never put secrets in `harness/wekan.json` or commit the credentials file.
- Never use `POST /users/login` to obtain a token (fails for API users).
- Never block the SDD flow on Wekan errors — log and continue.
- Never invent dates: leave `dueAt`/`startAt`/`endAt` empty unless specified.
````

- [ ] **Step 6: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `FAIL: 0`.

- [ ] **Step 7: Commit**

```bash
git add templates/modules tests/test-install.sh
git commit -m "feat: wekan-tickets module mirroring SDD states on Wekan"
```

---

### Task 10: Interactive module menu + audit-level prompt (mandatory, §4.2)

The module menu is **mandatory in interactive mode**: every available module is listed with its one-line description; the user selects any subset (default: none); stack-incompatible selections are marked and skipped with a warning. EOF-safe reads keep piped-input tests (`printf 'o\n'`) working with defaults.

**Files:**
- Modify: `init.sh` (convert the module-selection block into if/else — see Step 3)
- Test: `tests/test-install.sh` (3 new test sub-cases in one function)

**Interfaces:**
- Consumes: `MODULES_AVAILABLE`, `module_supports_stack`, `manifest_str` (Task 4).
- Produces: filled `MODULES_SELECTED` / `AUDIT_LEVEL` before the copy phase.

- [ ] **Step 1: Write the failing tests**

```bash
test_interactive_module_menu() {
  local t="interactive menu lists every module; empty answers install none"
  run_test "$t"
  local d; d=$(new_project "interactive-menu")
  local out
  out="$(cd "$d" && printf 'o\n\n\n' | "$INIT" 2>&1)" || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  printf '%s\n' "$out" > "$d/init-output.txt"
  for m in architecture-catalog iterative-refinement decision-memory project-scanner security-audit performance-benchmarks wekan-tickets; do
    assert_grep "$t" "$m" "$d/init-output.txt"
  done
  assert_grep "$t" "Audit level" "$d/init-output.txt"
  assert_grep "$t" '"modules": \[\]' "$d/harness/feature_list.json"
  assert_grep "$t" '"audit_level": "basic"' "$d/harness/feature_list.json"
  assert_no_dir "$t" "$d/harness/tools"

  local t2="interactive menu accepts module selection by number"
  run_test "$t2"
  d=$(new_project "interactive-select")
  # menu order is the alphabetical module dir order; 1 = architecture-catalog
  out="$(cd "$d" && printf 'o\n1,99\n\n' | "$INIT" 2>&1)" || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t2: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  printf '%s\n' "$out" > "$d/init-output.txt"
  assert_file "$t2" "$d/docs/architecture-options.md"
  assert_grep "$t2" '"architecture-catalog"' "$d/harness/feature_list.json"
  assert_grep "$t2" "Ignoring invalid module number" "$d/init-output.txt"

  local t3="interactive audit level prompt accepts standard"
  run_test "$t3"
  d=$(new_project "interactive-audit")
  (cd "$d" && printf 'o\n\n2\n' | "$INIT" >/dev/null) || {
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$t3: init.sh exited non-zero"); return
  }
  PASS=$((PASS + 1))
  assert_grep "$t3" '"audit_level": "standard"' "$d/harness/feature_list.json"
}
```

Call in Main after `test_invalid_tool_rejected` (grouping the interactive tests):

```bash
test_interactive_module_menu
```

Note: the existing `test_interactive_prompt` pipes only one line (`o\n` / `c\n`); the menu and audit prompts hit EOF and must default (none / basic) — verified implicitly by that test staying green.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-install.sh 2>&1 | tail -5`
Expected: `FAIL: 12` — no menu yet, so: 8 failures in the first sub-case (7 module names + "Audit level" missing from output), 3 in the second (no module installed, no warning), 1 in the third (`audit_level` stays `basic`).

- [ ] **Step 3: Convert the selection block into if/else in init.sh**

The Task 4 block currently ends with:

```bash
fi
# (the interactive module menu is added by a later task)

AUDIT_LEVEL="${AUDIT_LEVEL:-basic}"
```

Replace the closing `fi` of `if [ -n "$MODULES_FLAG" ]` **and** the placeholder comment with this `else` branch (so the whole block reads `if [ -n "$MODULES_FLAG" ]; then ...flag parsing... else ...menu... fi`):

```bash
else
  # Mandatory interactive menu (§4.2): every module is always presented.
  echo ""
  echo "Optional capability modules (none are installed by default):"
  declare -A MENU_MAP=()
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
```

(The `read -r answer || answer=""` pattern makes prompts EOF-safe so piped input and non-interactive shells fall back to defaults. The `AUDIT_LEVEL="${AUDIT_LEVEL:-basic}"` line from Task 4 sits right after this whole if/else block and stays.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `FAIL: 0` — including the pre-existing `test_interactive_prompt` (EOF defaults) and `test_reinstall_refused`.

- [ ] **Step 5: Commit**

```bash
git add init.sh tests/test-install.sh
git commit -m "feat: mandatory interactive module menu and audit-level prompt"
```

---

### Task 11: Role templates + AGENTS.md conditional instructions (§4.3-§4.6)

Zero new roles, zero new states (§2 "Variant chosen: light"). Conditional instructions gate on file/config presence, so agents without the module behave exactly as today. All six role templates get the same conditional text (tool-specific paths differ).

**Files:**
- Modify: `templates/.claude/agents/spec-author.md`, `templates/.opencode/agent/spec-author.md`
- Modify: `templates/.claude/agents/reviewer.md`, `templates/.opencode/agent/reviewer.md`
- Modify: `templates/.claude/agents/leader.md`, `templates/.opencode/agent/leader.md`
- Modify: `templates/AGENTS.md`

**Interfaces:**
- Consumes: destinations produced by modules — `docs/architecture-options.md`, `harness/decisions/_template.md`, `harness/tools/audit-security.sh`, `harness/tools/bench.sh`, `harness/tools/scan.py`, `harness/wekan.json`, `docs/architecture-options.md`; `audit_level` key in `harness/feature_list.json`; C7 in installed `harness/CHECKPOINTS.md`; `wekan-tasks` skill (installed per tool).

- [ ] **Step 1: spec-author — Architectural Decisions section (both copies)**

In `templates/.claude/agents/spec-author.md` and `templates/.opencode/agent/spec-author.md`:

a) Change protocol step 4 to:

```
4. Write `design.md`: files to modify, new signatures, exceptions, one discarded alternative with justification. Include the standard `## Architectural Decisions` section (see below) — delete it only if the feature has no significant decisions.
```

b) Add a new section after `## EARS Notation Reference`:

````markdown
## Architectural Decisions (standard design.md section)

`design.md` must contain this section:

```markdown
## Architectural Decisions
<!-- One entry per significant decision. Delete if none. -->
```

Each entry follows ADR form: **Context / Decision / Alternatives considered /
Consequences**. The existing human approval gate at `spec_ready` reviews these
decisions — no extra gate.

Conditional capabilities (active only when the module is installed):
- If `docs/architecture-options.md` exists → consult it when filling the
  Architectural Decisions section.
- If `harness/decisions/_template.md` exists → decisions worth remembering beyond
  this feature are ALSO copied to `harness/decisions/<feature>-<slug>.md`
  (one ADR per file, immutable, based on `_template.md`).
````

- [ ] **Step 2: reviewer — conditional audits (both copies)**

In `templates/.claude/agents/reviewer.md` and `templates/.opencode/agent/reviewer.md`, add after the `## Protocol` section:

````markdown
## Conditional audits (only when the module is installed)

Read `"audit_level"` from the `project` section of `harness/feature_list.json`
(absent or `basic` → no scripted audit):

- **basic** — read the "Security Audit Checklist" section of `docs/verification.md`
  and confirm each item manually; record the confirmation in the review file.
- **standard** (when `harness/tools/audit-security.sh` exists) — run
  `bash harness/tools/audit-security.sh` before the verdict, append the report to
  `harness/progress/review_<name>.md`. Reject approval if it reports HIGH findings.
- **strict** (additionally, when `harness/tools/bench.sh` exists) — run
  `bash harness/tools/bench.sh`; reject if a benchmark regresses beyond the
  critical threshold defined in `harness/baselines.json`.

Checkpoint **C7** in `harness/CHECKPOINTS.md` (when present) reflects these rules.
````

- [ ] **Step 3: leader — project-scanner + wekan traces (both copies)**

In `templates/.claude/agents/leader.md` and `templates/.opencode/agent/leader.md`, add after the `## Startup Protocol` section:

````markdown
## Conditional capabilities (only when the module is installed)

- **project-scanner** — if `harness/tools/scan.py` exists: in the Startup
  Protocol, after `harness/init.sh` passes, run
  `python3 harness/tools/scan.py --summary` and note the output summary in
  `harness/progress/current.md`. After implementation, optionally re-run with
  `--impact <changed-file>` for impact analysis of the touched files.
- **wekan-tickets** — if `harness/wekan.json` exists and `"enabled"` is not
  `false`: follow the installed `wekan-tasks` skill to mirror every state
  transition on the board, and write the card id back as `"wekan_card": "<id>"`
  on the feature object when you create a card. Wekan failures are logged in
  `harness/progress/current.md` and never block the flow.
````

- [ ] **Step 4: AGENTS.md — conditional repo-map rows**

In `templates/AGENTS.md`, add these rows at the end of the §2 repository map table:

```markdown
| `docs/architecture-options.md` | Architecture pattern catalog (module: architecture-catalog) | When filling design.md Architectural Decisions |
| `docs/iteration-protocol.md`   | Adaptive iteration + adversarial review protocol (module: iterative-refinement) | During implementer refinement rounds |
| `harness/tools/`               | Module tools: `audit-security.sh`, `bench.sh`, `scan.py` (if present) | On review (audits) or session start (scan) |
| `harness/decisions/`           | ADRs worth remembering beyond a feature (if present) | Before proposing a new architectural decision |
| `harness/wekan.json`           | Wekan ticket-mirror config (if present) | When syncing workflow state to the board |
```

And add this note right after the table:

```markdown
> Module files are conditional: if a file above exists, its module was installed —
> follow it. If absent, ignore references to it.
```

- [ ] **Step 5: Run the full suite (no behavioral change expected)**

Run: `bash tests/test-install.sh 2>&1 | tail -3`
Expected: `FAIL: 0` (templates are copied verbatim; existing assertions still pass).

- [ ] **Step 6: Commit**

```bash
git add templates/AGENTS.md templates/.claude/agents templates/.opencode/agent
git commit -m "feat: module-conditional instructions in role templates and repo map"
```

---

### Task 12: README documentation + final verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the modules section to README.md**

Insert after the "Quick start" section (after line 30, before "### Reinstalling"):

````markdown
### Optional capability modules

During an interactive install you can pick optional modules from a menu (default: none).
Non-interactive: `--modules=m1,m2` and `--audit-level=basic|standard|strict` (default `basic`).

| Module | What it adds |
|---|---|
| `architecture-catalog` | `docs/architecture-options.md` — pattern catalog for design decisions |
| `iterative-refinement` | `docs/iteration-protocol.md` — adaptive iteration + adversarial review protocol |
| `security-audit` | Security checklist in `docs/verification.md`, `harness/tools/audit-security.sh`, checkpoint C7 |
| `performance-benchmarks` | Benchmark rules, `harness/tools/bench.sh`, `harness/baselines.json`, checkpoint C7 |
| `decision-memory` | `harness/decisions/` with an ADR template |
| `project-scanner` | `harness/tools/scan.py` — deterministic Python scanner (python stack only) |
| `wekan-tickets` | `wekan-tasks` skill + `harness/wekan.json` — mirrors workflow states on a Wekan board |

Example:

```bash
/path/to/harness-standard/init.sh --tool=opencode --modules=security-audit,performance-benchmarks --audit-level=strict
```
````

Also update the "Feature list format" example project section to:

```json
  "project": {
    "name": "my-project",
    "parallel": false,
    "modules": ["security-audit"],
    "audit_level": "standard"
  },
```

And add to the "Directory structure" tree, inside `harness/` (before `specs/`):

```
    ├── tools/                # Module tools (if modules installed)
    ├── baselines.json        # Benchmark baselines (if benchmarks module)
    ├── decisions/            # ADRs (if decision-memory module)
    ├── wekan.json            # Wekan mirror config (if wekan-tickets module)
```

And append to the "### Reinstalling" section (after the existing paragraph about preserved user state):

```markdown
> **Switching module sets with `--force`:** the `modules` and `audit_level` entries in `harness/feature_list.json` are updated to the new selection, but files belonging to removed modules are **not** deleted automatically — remove them by hand (e.g. `harness/tools/scan.py`, `docs/architecture-options.md`, `harness/tools/bench.sh`). User-state files (`harness/baselines.json`, `harness/wekan.json`, `harness/decisions/`) are always preserved.
```

- [ ] **Step 2: Full suite + manual smoke of both menus**

Run: `bash tests/test-install.sh`
Expected: `FAIL: 0` (≈145 PASS).

Run a manual smoke in a scratch dir:

```bash
d=$(mktemp -d /tmp/opencode/smoke-XXXX)
cd "$d" && bash /home/jordi/works/harness-standard/init.sh   # answer: o, 1,6, 2
ls docs/ harness/tools/ && cat harness/feature_list.json
```

Expected: menu shows all 7 modules; `architecture-catalog` + `security-audit` installed; `audit_level: standard`; C7 present in `harness/CHECKPOINTS.md`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document optional capability modules and installer flags"
```

---

## Spec coverage check (self-review)

| Spec section | Task(s) |
|---|---|
| §2 six+one modules, light variant | Tasks 2, 3, 5, 6, 7, 9 |
| §3 module tree + destinations | Tasks 2, 3, 5, 6, 7, 9 (all files above) |
| §3.1 manifest schema incl. tool_dst | Task 4 parser + Task 9 wekan manifest |
| §4.1 feature_list modules + audit_level | Task 4 (template keys), Task 11 (consumers) |
| §4.2 init.sh flags, mandatory menu, injection, validation, --force | Tasks 4, 6, 8, 10 |
| §4.3 spec-author decisions + decision-memory | Task 11 step 1 |
| §4.4 reviewer audits + C7 | Tasks 6, 11 step 2 |
| §4.5 leader scanner | Task 11 step 3 |
| §4.6 conditional role templates + entry-point docs | Task 11 (AGENTS.md rows; only generic CLAUDE.md.tpl mentions docs/, no list to extend) |
| §4.7 wekan adaptation (lists, traces, config, secrets, traceability) | Task 9 |
| §5 audit levels (tools run by reviewer, never installer) | Tasks 6, 7 scripts + Task 11 reviewer text |
| §6 content corrections | Tasks 2 (§6.1), 3 (§6.1), 5 (D fixes), 6 (§6.2 headers/OWASP), 7 (A fixes), 9 (C dropped → ADRs) |
| §7 fate of source docs | Task 1 |
| §8 tests 1-8 | 8.1→Task 7, 8.2→Task 4, 8.3→Task 2, 8.4→Task 8, 8.5→Task 5, 8.6→Task 9, 8.7→Task 10, 8.8→every task |
| §9 out of scope | Nothing added beyond it (no new roles/states, no CI, no multi-language scanner) |

Deliberate decisions (flag to reviewer if disagreeing):
1. **`copy-if-missing` is a third inject mode** — §3.1 names two modes but §3 marks `baselines.json` and `wekan.json` "(if not present)"; a mode is the cleanest encoding.
2. **C7 lives in `templates/modules/_shared/c7-audit.md`** and is injected with module name `audit-checkpoint` — keeps it data-driven and `--force`-safe like any other section.
3. **Manifests are parsed with sed/grep**, hence the strict format discipline in Global Constraints — keeps `init.sh` dependency-free for generic-stack projects.
4. **`--force` refreshes module metadata best-effort** — `modules`/`audit_level` lines are sed-replaced in the existing `feature_list.json` (Task 8); other feature data is never touched. If the lines are missing (hand-reformatted file), it warns with manual instructions instead of failing.

Known limitations (accepted for v1, documented in the README by Task 12):

- `--force` with a **different** module set updates the metadata but does NOT delete files of unselected modules — `copy`-mode artifacts (e.g. `harness/tools/scan.py`, `docs/architecture-options.md`, `harness/tools/bench.sh`) linger until removed by hand. `append-section` content self-heals (base files are re-copied and only selected modules re-injected), and `copy-if-missing` user state persists by design. Safe orphan cleanup would require parsing the previous module set from `feature_list.json` — deferred.
- A piped (non-interactive) `--force` resets metadata to the EOF defaults (`[]` / `basic`), reflecting what that run actually injected.
5. **Interactive menu appears whenever `--modules` is absent** (not TTY-gated) — matches "mandatory in interactive mode" and keeps piped tests deterministic via EOF-safe defaults.

## Execution Handoff

After review approval, execute with **superpowers:subagent-driven-development** (recommended: fresh subagent per task, two-stage review) or **superpowers:executing-plans** (inline, batched with checkpoints). Tasks 2-11 depend on their predecessors' interfaces; do not reorder. Task 1 is independent and can run anytime.
