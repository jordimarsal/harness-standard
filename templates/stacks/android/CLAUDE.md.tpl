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

## Stack: Android
- **Build tool:** Gradle (`./gradlew`)
- **Testing:** `./gradlew test` (unit) + `./gradlew connectedAndroidTest` (instrumented)
- **Build:** `./gradlew assembleDebug`
- **Language:** Kotlin preferred, Java accepted
- **Key conventions:**
  - Follow Android architecture guidelines (ViewModel, Repository pattern).
  - Kotlin: prefer data classes, sealed classes, coroutines.
  - One class per file, package-by-feature organization.
  - Use `androidx` libraries.
  - No hardcoded strings — use resource files.
  - Min SDK and target SDK as specified in build.gradle.
