# Harness Standard

A standardized multi-agent harness for Claude Code and opencode. Installs into any project with a single command.

## What it does

- **2 tools**: Claude Code (`CLAUDE.md` + `.claude/`) or opencode (`AGENTS.md` + `.opencode/`)
- **4 agent roles**: Leader (orchestrator), Spec Author (writes specs), Implementer (writes code), Reviewer (validates)
- **Mandatory SDD**: All features follow Spec Driven Development with human approval gates
- **7 stacks**: TypeScript, Node.js, Java, Python, Android, Rust, Generic
- **Parallelism**: Configurable sequential or parallel task execution

## Quick start

```bash
cd /path/to/your/project
/path/to/harness-standard/init.sh
```

The installer asks whether the harness will be driven by **claude** or **opencode**, detects your tech stack, copies templates, and sets up the harness. For non-interactive use:

```bash
/path/to/harness-standard/init.sh --tool=claude
/path/to/harness-standard/init.sh --tool=opencode
```

- **claude** generates `CLAUDE.md` and `.claude/` at the project root.
- **opencode** generates `AGENTS.md` and `.opencode/` (plus `opencode.json`) at the project root.

Everything else groups under `harness/`; only `docs/` stays at the project root.

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

### Reinstalling

The installer refuses to run twice in the same project. To reinstall (e.g. to switch tool or refresh templates), use `--force`:

```bash
/path/to/harness-standard/init.sh --force --tool=opencode
```

`--force` refreshes all templates but preserves user state: `harness/feature_list.json`, `harness/progress/`, `harness/specs/`, `docs/architecture.md` and `docs/conventions.md`.

> **Switching module sets with `--force`:** the `modules` and `audit_level` entries in `harness/feature_list.json` are updated to the new selection, but files belonging to removed modules are **not** deleted automatically — remove them by hand (e.g. `harness/tools/scan.py`, `docs/architecture-options.md`, `harness/tools/bench.sh`). User-state files (`harness/baselines.json`, `harness/wekan.json`, `harness/decisions/`) are always preserved.

## After installation

1. Edit `docs/architecture.md` with your project's architecture principles.
2. Edit `docs/conventions.md` with your coding conventions.
3. Add features to `harness/feature_list.json`.
4. Start Claude Code or opencode — the leader agent will guide you through the SDD workflow.

## SDD Workflow

```
pending → [spec-author] → spec_ready → ⏈ HUMAN APPROVAL → in_progress → [implementer → reviewer] → done
```

Every feature goes through:

1. **Spec writing** — spec-author creates requirements, design, and tasks
2. **Human approval** — you review and approve the spec
3. **Implementation** — implementer writes code and tests task by task
4. **Review** — reviewer validates traceability and completion

## Feature list format

```json
{
  "project": {
    "name": "my-project",
    "parallel": false,
    "modules": ["security-audit"],
    "audit_level": "standard"
  },
  "features": [
    {
      "id": 1,
      "name": "feature_name",
      "title": "Feature Title",
      "description": "What this feature does.",
      "acceptance": ["Criterion 1", "Criterion 2"],
      "status": "pending"
    }
  ]
}
```

## Stack detection priority

1. TypeScript (`tsconfig.json`)
2. Node.js (`package.json` without `tsconfig.json`)
3. Android (`build.gradle` + `AndroidManifest.xml`)
4. Java (`build.gradle` or `pom.xml`)
5. Python (`requirements.txt` or `pyproject.toml`)
6. Rust (`Cargo.toml`)
7. Generic (fallback)

## Directory structure (after installation)

```
your-project/
├── CLAUDE.md  or  AGENTS.md # Entry point (depends on chosen tool)
├── .claude/  or  .opencode/ # Tool directory (agents + settings)
├── opencode.json            # opencode only: permissions
├── docs/                    # Stays at the project root
│   ├── architecture.md      # Your architecture principles
│   ├── conventions.md       # Your coding conventions
│   ├── specs.md             # SDD process documentation
│   └── verification.md      # How to verify work
└── harness/                 # Everything else, grouped
    ├── CHECKPOINTS.md       # Completion criteria
    ├── feature_list.json    # Feature tracking
    ├── init.sh              # Verification script
    ├── progress/            # Session state
    │   ├── current.md
    │   └── history.md
    ├── tools/                # Module tools (if modules installed)
    ├── baselines.json        # Benchmark baselines (if benchmarks module)
    ├── decisions/            # ADRs (if decision-memory module)
    ├── wekan.json            # Wekan mirror config (if wekan-tickets module)
    └── specs/               # Feature specs (created per feature)
```

## Running the verification

From the project root:

```bash
./harness/init.sh
```
