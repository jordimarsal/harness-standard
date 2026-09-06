# Design: Optional capability modules for harness-standard

**Date:** 2026-09-06
**Status:** Approved design, pending implementation plan
**Source material:** `agent_prompt.md` and `annex.md` (moved to `docs/reference/` by this work)

## 1. Problem

`agent_prompt.md` and `annex.md` describe valuable agent capabilities (architecture
selection, iterative refinement, adversarial review, performance benchmarking, security
audit, project memory, deterministic project reading), but they are written for a
different paradigm than the harness this repo installs:

| | `agent_prompt.md` + `annex.md` | Installed harness (`templates/`) |
|---|---|---|
| Model | Single agent printing code in chat, 5 fixed rounds | Multi-agent SDD (leader / spec-author / implementer / reviewer) |
| State | Conversation | Files (`feature_list.json`, `progress/`) |
| Verification | "mentally" | Real tools via bash (`harness/init.sh`) |
| Stack | Python only | 7 stacks |
| Output | `## ITERATION #N` in chat | Commits + `progress/current.md` |

Additionally, the source documents contain concrete defects: a broken/duplicated code
block (`agent_prompt.md` §4), invalid JSON (`True` instead of `true`, annex.md §C.2),
deprecated `datetime.utcnow()`, a hand-rolled benchmark runner inferior to
`pytest-benchmark`, deprecated security headers, and logic bugs in the Annex D scanner
(double parse, broken dependency matching).

Not every project needs every capability. Forcing all of them into the core harness
would add friction to simple projects.

## 2. Decision

Migrate the content of both documents into **six optional modules** under
`templates/modules/`, installable via `init.sh`, and fix all defects during migration.

**Variant chosen: light.** Zero new agent roles, zero new workflow states. Existing
roles (spec-author, reviewer, leader) absorb the new responsibilities conditionally.

Seven modules total; the seventh (`wekan-tickets`) adapts the external
`wekan-tasks` skill (§4.7).

## 3. Module structure

```
templates/modules/
├── architecture-catalog/
│   ├── manifest.json
│   └── architecture-options.md        → docs/architecture-options.md
├── iterative-refinement/
│   ├── manifest.json
│   └── iteration-protocol.md          → docs/iteration-protocol.md
├── security-audit/
│   ├── manifest.json
│   ├── verification-audit.md          → appended to docs/verification.md
│   └── audit-security.sh              → harness/tools/audit-security.sh
├── performance-benchmarks/
│   ├── manifest.json
│   ├── verification-benchmarks.md     → appended to docs/verification.md
│   ├── bench.sh                       → harness/tools/bench.sh
│   └── baselines.json                 → harness/baselines.json (if not present)
├── decision-memory/
│   ├── manifest.json
│   └── ADR-template.md                → harness/decisions/_template.md
└── project-scanner/
    ├── manifest.json
    └── scan.py                        → harness/tools/scan.py
```

`wekan-tickets/` additionally exists (see §4.7):

```
wekan-tickets/
├── manifest.json
├── SKILL.md                           → .opencode/skill/wekan-tasks/SKILL.md
│                                       or .claude/skills/wekan-tasks/SKILL.md
└── wekan.json                         → harness/wekan.json (if not present)
```

Its destination depends on the chosen driving tool, so its manifest declares a
`tool_dst` variant (see §3.1).

### 3.1 Manifest schema

Every module directory contains `manifest.json` with exactly these keys:

```json
{
  "name": "security-audit",
  "description": "One-line description shown by the installer.",
  "stacks": ["python", "generic"],
  "injects": [
    { "src": "verification-audit.md", "dst": "docs/verification.md", "mode": "append-section" },
    { "src": "audit-security.sh", "dst": "harness/tools/audit-security.sh", "mode": "copy" }
  ],
  "verify": ["harness/tools/audit-security.sh"]
}
```

- `stacks`: stacks the module supports. The installer skips (with a warning) a selected
  module whose `stacks` list excludes the detected stack.
- `mode: "copy"` — plain file copy. `mode: "append-section"` — append the source content
  to the destination file wrapped in per-module markers:

  ```
  <!-- harness:module:<name>:start -->
  ...module content...
  <!-- harness:module:<name>:end -->
  ```

  Multiple modules may append to the same file; each section is independent.
  `--force` replaces only the content between that module's own markers, never another
  module's section.
- `verify`: paths that must exist after installation for the module to count as valid.
- `dst` may be a plain path or an object keyed by tool for tool-dependent destinations:
  `{"claude": ".claude/skills/wekan-tasks/SKILL.md", "opencode": ".opencode/skill/wekan-tasks/SKILL.md"}`.
  The installer resolves it with the chosen `--tool`.

## 4. Integration points (0 new roles, 0 new states)

### 4.1 `feature_list.json`

The `project` section (which already holds `parallel`) gains:

```json
"project": {
  "name": "my-project",
  "parallel": false,
  "modules": ["security-audit", "project-scanner"],
  "audit_level": "standard"
}
```

- `modules`: installed module names. Written by the installer.
- `audit_level`: `"basic"` (default) | `"standard"` | `"strict"`. Only meaningful when a
  module that performs audits is installed.

### 4.2 `init.sh`

Following the existing `--tool` pattern (interactive prompt + non-interactive flag):

- New interactive prompts: module multi-select (numbered list from scanning
  `templates/modules/*/manifest.json`, filtered by detected stack) and audit level.
  **All modules are always presented**: the menu is mandatory in interactive mode —
  every available option is shown with its one-line description; the user selects any
  subset (default: none). Stack-incompatible modules appear greyed/marked with a
  warning and are skipped if selected.
- New flags: `--modules=security-audit,project-scanner` and `--audit-level=basic|standard|strict`.
- Default (no flags, no answers): core harness only — **byte-identical behavior to the
  current installer** except for the new `modules: []` and `audit_level: "basic"` keys
  in `feature_list.json`.
- Injection happens after the base template copy, before validation. Validation gains a
  per-module check from each manifest's `verify` list.
- `--force`: refreshes module files and re-injects `append-section` content without
  duplicating; preserves `harness/baselines.json`, `harness/decisions/`,
  `harness/wekan.json` (user state).

### 4.3 spec-author (architecture-catalog, decision-memory)

- The spec-author role templates (`templates/.claude/agents/spec-author.md` and
  `templates/.opencode/agent/spec-author.md`, which carry the inline `design.md`
  structure — `templates/specs/` is intentionally empty) gain the requirement to include
  a standard section in every `design.md`:

  ```
  ## Architectural Decisions
  <!-- One entry per significant decision. Delete if none. -->
  ```

  Each entry follows ADR form: **Context / Decision / Alternatives considered /
  Consequences**. If `architecture-catalog` is installed, spec-author consults
  `docs/architecture-options.md` when filling it.
- The existing human approval gate at `spec_ready` reviews these decisions. No new
  state: a feature without architectural decisions simply omits the section.
- When `decision-memory` is installed, decisions worth remembering beyond the feature
  are also copied to `harness/decisions/<feature>-<slug>.md` (one ADR per file,
  immutable, using `_template.md`).

### 4.4 reviewer (security-audit, performance-benchmarks)

- The reviewer checklist gains a conditional block, active only when `audit_level` is
  set and a matching module is installed: run (or read the report of)
  `harness/tools/audit-security.sh` / `harness/tools/bench.sh` before approving.
- `CHECKPOINTS.md` gains section **C7 — Audit (conditional)**, appended by the installer
  only when an audit module is installed. C7 asserts: latest audit report exists in the
  progress entry; findings above the level's threshold are resolved or explicitly waived.

### 4.5 leader (project-scanner)

- If `project-scanner` is installed: at session start (after `harness/init.sh`), run
  `python3 harness/tools/scan.py --summary` and note the output summary in
  `harness/progress/current.md`. After implementation, optionally re-run for impact
  analysis of changed files.

### 4.6 Role templates (all modules)

The behavior described in §4.3–§4.5 and §4.7 (role traces on Wekan cards) is written
into the existing role templates —
`templates/.claude/agents/{spec-author,reviewer,leader}.md` and
`templates/.opencode/agent/{spec-author,reviewer,leader}.md` — as **conditional
instructions** gated on the presence of the module's injected artifacts (e.g. "if
`docs/architecture-options.md` exists, consult it when filling Architectural
Decisions"). Agents without the module installed behave exactly as today; the
conditions check file/config presence, so no template duplication is needed. Where a
stack entry-point template (`templates/stacks/*/CLAUDE.md.tpl`, `templates/AGENTS.md`)
lists doc files to consult, the module-conditional docs are added there too.

### 4.7 wekan-tickets (external skill adaptation)

Adapts the existing `wekan-tasks` opencode skill (self-hosted Wekan kanban, REST API
via curl) into a harness module. When installed, **every workflow state transition is
mirrored on the Wekan board** — the card is the ticket; the harness remains the source
of truth, Wekan is the visible trace.

**Board model:**
- One board per project, titled with the project name from `feature_list.json`.
- Created on first use if missing (idempotent), with **standard lists named after the
  harness SDD states**: `pending`, `spec_ready`, `in_progress`, `blocked`, `done`.
  Card position == feature status; moving a card between lists == state transition.
  The list naming is overridable in `harness/wekan.json` (`"list_map": {...}`).

**Card lifecycle and role traces:**

| Event | Agent | Wekan action |
|---|---|---|
| Feature added / first seen at session start | leader | Create card (or find existing via `feature_list.json` card id); fill title + description (feature title, description, acceptance criteria) |
| Spec written | spec-author | Move card → `spec_ready`; comment with spec path |
| Human approves spec | leader | Move card → `in_progress` |
| Implementation starts | implementer | Set `startAt` to today |
| Task progresses / blocked | implementer | Comment with progress; if blocked move → `blocked` (and back when unblocked) |
| Review verdict | reviewer | Comment with verdict; on approval move → `done` and set `endAt` to today |
| Rework requested | reviewer | Move card back → `in_progress`; comment with findings |

**Config and secrets:**
- `harness/wekan.json` (committed, no secrets): `url`, `board_name` (default: project
  name), `list_map`, `credentials_file` (path to the gitignored env file),
  `enabled` (kill switch — agents skip Wekan actions when `false` or when the file is
  absent).
- Secrets stay outside the repo: `credentials_file` points to a gitignored env file
  with `WEKAN_API_BEARER_TOKEN` / `WEKAN_API_USER_ID`, read via bash `sed` (never via
  read tools; same pattern as the original skill).
- If credentials or the server are unreachable, agents log the failure in
  `progress/current.md` and continue — Wekan sync never blocks the SDD flow.

**Traceability field:**
- Each feature object in `feature_list.json` gains an optional `"wekan_card": "<id>"`
  written by the leader when the card is created, so agents never re-search the board.

**Adaptations from the original skill:**
- Homelab-specific data removed: hardcoded `viatgecio` board/list/label IDs, Catalan
  list names, fixed credential paths. Everything moves to `harness/wekan.json`.
- Standard lists change from `backlog/Sprint/Fent-ho/Blocat/Fet/Enviat` to the harness
  SDD states (1:1 mapping, overridable).
- SKILL.md rewritten in English (repo convention) and restructured around the role
  traces table above; the low-level API reference (auth quirks, `sed` token extraction,
  `swimlaneId` requirement, error table, mongo board-lookup fallback) is preserved.
- Delivered as a real skill for both tools: `.opencode/skill/wekan-tasks/` for opencode,
  `.claude/skills/wekan-tasks/` for claude (per-tool `dst` in the manifest).
- Stacks: all 7 (tool-agnostic HTTP).

## 5. Audit levels

`harness/tools/audit-security.sh` and `harness/tools/bench.sh` are run by the reviewer,
never inside `harness/init.sh` (whose contract remains: environment + tests green →
`[OK]`).

| Level | Behavior |
|---|---|
| `basic` | Reviewer reads and confirms the security checklist (from `verification-audit.md`) manually. No scripts required. |
| `standard` | Reviewer runs `audit-security.sh`: stack-appropriate SAST and dependency scans (see §6.3). Report appended to the progress entry. HIGH severity findings reject approval. |
| `strict` | Standard + reviewer runs `bench.sh`: benchmarks via the stack's framework compared against `harness/baselines.json` when a baseline exists. Regression beyond threshold rejects approval. |

- `baselines.json` starts empty (`{}`); thresholds are added per function once a first
  measurement exists. Without a baseline, strict-mode benchmarks only record values and
  warn.
- Audit findings are recorded in the feature's progress entry with severity
  (HIGH/MEDIUM/LOW), description, and resolution or waiver.

## 6. Content corrections applied during migration

### 6.1 From `agent_prompt.md`

| Original defect | Correction in module |
|---|---|
| §1 lists "Microservices / Modular Monolith" as one option | Split into two options with independent trade-offs |
| §1 forces architecture choice for every task | Catalog is reference material; selection happens in `design.md` only when relevant |
| §1 options lack negative guidance | Each option gains "when NOT to use" |
| §2 five fixed rounds | Adaptive protocol: full rounds for large features; scaled-down (self-review → fix → verify) for small ones, aligned with the leader's effort scaling table |
| §2 Phase 4 "run coverage analysis mentally" | Real commands: `pytest --cov`, `ruff`, `mypy`, `mutmut` (per stack equivalents) |
| §3 adversarial self-review (self-bias) | Becomes reviewer checklist items within `iteration-protocol.md` |
| §4 broken/duplicated code block | Fixed; also removes JUnit reference from the Python context |
| §4 hardcoded coverage targets | Default targets live in `iteration-protocol.md`; projects may override them in `docs/verification.md`. The installer does not edit `docs/verification.md` for this module |
| §6 chat response format | Replaced by iteration report section appended to `progress/current.md` |
| §7 pattern lists without selection criteria | Merged into `architecture-options.md` with trade-offs |

### 6.2 From `annex.md`

| Original defect | Correction in module |
|---|---|
| A.2 hand-rolled `BenchmarkRunner` (wall-clock only, naive percentiles, last-iteration result) | Use `pytest-benchmark` (or stack equivalent); `bench.sh` wraps it. Hand-rolled runner dropped |
| A.4 verbose mandatory output | Compact report template; only required when benchmarks module installed and feature touches hot paths |
| B.1/B.4 outdated headers (`X-XSS-Protection` deprecated) | Modern set: `Permissions-Policy`, `Referrer-Policy`, `Content-Security-Policy`, HSTS; drop `X-XSS-Protection` |
| B security checks are prose only | Mapped to OWASP Top 10 categories; automated where tooling exists |
| B.3 unrealistic rate-limit test (assumes concrete implementation) | Removed; checklist item remains |
| C.2 invalid JSON (`True`/`true`), C.3 `datetime.utcnow()` deprecated, non-atomic read-modify-write, unbounded growth | JSON memory system dropped entirely; replaced by markdown ADRs (`decision-memory`) + learnings section in `progress/history.md` |
| D.3/D.4 double parse per file, broken dependency matching (absolute path vs module name), linear scans | `scan.py` fixed: single parse pass, module-name resolution, dict indexes |
| D.5 protocol (the valuable part) | Preserved as scan.py behavior: read structure → impact analysis → duplicate check → style sampling → summary |

### 6.3 Per-stack audit tool table (security-audit, performance-benchmarks)

| Stack | SAST / deps (standard) | Benchmarks (strict) |
|---|---|---|
| python | `bandit`, `pip-audit` | `pytest-benchmark` |
| typescript / node | `npm audit` / `pnpm audit`, `eslint` security rules | `vitest bench` (if configured; otherwise record-only) |
| java / android | OWASP dependency-check (if configured; otherwise checklist-only) | checklist-only |
| rust | `cargo audit`, `cargo clippy` | `cargo bench` (if configured) |
| generic | checklist-only | checklist-only |

When a tool is not installed or not configured, the audit script degrades to
checklist-only and says so in its report — it must never fail the install.

## 7. Fate of the source documents

- `agent_prompt.md` and `annex.md` move to `docs/reference/` (traceability of source
  material). The installer never reads them.
- New modules are the single source of truth going forward.

## 8. Tests

Extend `tests/test-install.sh` (following its existing pattern):

1. Install with `--tool=opencode --modules=security-audit,performance-benchmarks --audit-level=strict`:
   - injected files exist (`harness/tools/audit-security.sh`, `harness/tools/bench.sh`,
     `harness/baselines.json`);
   - `docs/verification.md` contains both module sections exactly once;
   - `CHECKPOINTS.md` contains C7;
   - `feature_list.json` project section contains the modules and audit level.
2. Install with no module flags: output equivalent to current behavior; `feature_list.json`
   contains `"modules": []` and `"audit_level": "basic"`; no `harness/tools/` directory.
3. Manifest validation: every `templates/modules/*/manifest.json` parses as JSON and has
   all required keys; every `injects[].src` and `verify[]` path exists in the module dir.
4. `--force` reinstall with modules: injected sections are replaced, not duplicated;
   `harness/baselines.json` and `harness/decisions/` preserved.
5. Module filtered by stack: selecting a module whose `stacks` excludes the detected
   stack produces a warning and skips injection, install still succeeds.
6. Install with `--tool=claude --modules=wekan-tickets`:
   - `.claude/skills/wekan-tasks/SKILL.md` exists (and the `.opencode` path does NOT);
   - `harness/wekan.json` exists, valid JSON, contains `url`, `list_map`,
     `credentials_file`, `enabled` — and no secrets;
   - `harness/wekan.json` is listed as preserved user state under `--force`.
   Same assertions with `--tool=opencode` for `.opencode/skill/wekan-tasks/SKILL.md`.
   No live Wekan API calls in tests — only file assertions.
7. Interactive menu test (piped input): answering the module prompt lists all modules
   with descriptions; selecting none yields the same result as case 2.
8. Re-run `bash tests/test-install.sh` (existing tests) — no regressions.

## 9. Out of scope (v1)

- New agent roles (architect, quality-auditor) or workflow states
  (`pending_arch_decision`, `auditing`).
- JSON memory system, cross-stack scanners (v1 scanner: Python AST + generic file
  fallback), CI integration, multi-language scan.py.
- Live Wekan integration testing (board creation, card moves) — the module ships the
  skill and config; API behavior is inherited from the battle-tested original skill.
