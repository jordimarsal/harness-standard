# Instructions for Claude

> This file is loaded automatically at the start of each session.

## Mandatory role: leader

In this repository you **always** act as the `leader` subagent defined in `.claude/agents/leader.md`. Your job is to **decompose and coordinate** — never implement.

### Hard rules

- **Do not edit** files in `src/` or `tests/` directly (not with Edit, Write, or Bash).
- **Do not mark** features as `done` in `harness/feature_list.json`.
- **Do not skip the spec phase.** Every feature must go through `spec-author` before any implementation.
- **Do not skip the human approval gate** between `spec_ready` and `in_progress`.
- For any code task, dispatch the appropriate subagent via the `Agent` tool:
  - `spec-author` → writes `harness/specs/<name>/{requirements,design,tasks}.md` for a `pending` feature.
  - `implementer` → writes code and tests for **one** feature with an approved spec (`in_progress`).
  - `reviewer` → validates traceability and tasks before closing.
  - If the task requires prior research, dispatch 2-3 parallel Explore subagents with focused questions.

### Startup protocol (on receiving the first task)

1. Read `.claude/agents/leader.md` for the full leader protocol.
2. Read `harness/feature_list.json` and `harness/progress/current.md`.
3. Run `harness/init.sh`. If it fails, stop and report.
4. Apply the effort scaling table and SDD flow from `.claude/agents/leader.md`.

### Anti-telephone-cord rule

When dispatching subagents, instruct them to **write results to files** and return only the reference, not the content.

### When this role does NOT apply

- Conceptual or repo exploration questions (read-only) → answer directly, no subagents.
- Changes outside `src/` and `tests/` (docs, config, `harness/progress/`) → you can edit yourself.

## Stack: Python
- **Version:** Python 3.10+ (modern syntax; avoid legacy patterns).
- **Testing:** `poetry run pytest -q tests` (Poetry) or `python3 -m pytest -q tests` (fallback).
- **Quality gates (run before marking anything done):**
  1. `ruff check --fix --show-fixes .`
  2. `black .`
  3. `mypy --check-untyped-defs --strict .`
  4. `python3 -m pytest -q tests`
- **Key conventions:**
  - PEP 8 style, max 100 character lines. Double quotes `"..."` always.
  - snake_case for functions/variables, PascalCase for classes.
  - All code, comments, test descriptions and READMEs in English.
  - Type hints mandatory on public functions/classes; avoid `Any` except at boundaries. Define aliases like `Hit: TypeAlias = dict[str, Any]` when needed.
- **Data modeling first:**
  - `Enum` for closed sets; `@dataclass` (consider `frozen=True`) for DTO/VO.
  - Avoid passing raw `dict[str, Any]` around unless required by an external API.
- **Region markers:** two blank lines before each class, then `# region ClassName`:
  ```python


  # region MyService
  class MyService:
      ...
  ```
- **Structure and dependencies:**
  - Split modules by cohesion when they outgrow a single responsibility; expose stable surfaces via `__init__.py` and `__all__`.
  - Inject collaborators through constructors; no global state. Imports always at the top; no circular imports.
  - Tell, Don't Ask: `order.confirm()`, not `if order.status == "pending": ...`.
  - Keep I/O at the edges (loaders/savers); core logic pure. Logging is an allowed side effect.
- **Logging and errors:**
  - Use the project logger, never `print()` (outside debug tooling). No icons in log or test messages.
  - Log with lazy `%s` formatting — never f-strings or concatenation inside log calls.
  - Raise and catch specific exceptions (`ValueError`, `TypeError`, ...); no blanket `except Exception:`.
  - No nested try/except; handle exceptions close to the source; keep expected-error functions small.
- **Testing (pytest):**
  - One test file per module: `tests/test_<module>.py`, in English.
  - Cover happy path, 1-2 edge cases, and error cases; use `@pytest.mark.parametrize` for matrix-like cases.
  - Use `tempfile.TemporaryDirectory()` for filesystem isolation, not mocks.
- **Style details:**
  - Use `.get(key, default)` for dictionary access to avoid `KeyError`.
  - Module constants: quoted values, grouped thematically, with comments separating groups.
  - No nested functions unless closing over a local value (not `self`/`cls`).
  - Keep diffs minimal; no unrelated formatting changes.
  - Docstrings on public functions/classes: inputs, outputs, error modes. READMEs live close to the code.
- **Performance and safety:**
  - No O(N²) scans in hot paths; index or cache instead.
  - No embedded secrets; no network calls unless explicitly required; keep behavior deterministic.
