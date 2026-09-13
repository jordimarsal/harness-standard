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

## Stack: Java
- **Build tool:** Gradle (`./gradlew`) or Maven (`mvn`)
- **Testing:** `./gradlew test` or `mvn test`
- **Build:** `./gradlew build` or `mvn package`
- **Key conventions:**
  - Follow Java naming conventions (PascalCase classes, camelCase methods).
  - One public class per file.
  - Prefer immutability (final fields, records where applicable).
  - JUnit 5 for testing.
  - No commented-out code or debug prints.
  - Assume a modern Java LTS (21+): prefer `record` for immutable value objects, `Math.clamp(v, min, max)` over `Math.max(min, Math.min(v, max))`, and unnamed variables `_` for unused catch params (`catch (RuntimeException _)`).
  - **Logging:** never `System.out`/`System.err`; use the project's SLF4J logger. Pass the throwable as the last arg (`LOG.error("msg", e)`), and defer expensive args with a `Supplier` / `"{}"` lambda rather than precomputing the string.
  - **Resources:** wrap every `AutoCloseable` (stores, containers, pools, files) in **try-with-resources**. A class-scoped container started in `@BeforeAll`/`@AfterAll` that cannot use try-with-resources should be annotated `@SuppressWarnings("resource")` with a comment explaining why.
  - **APIs:** no wildcard return types — return `ApiResponse<Object>`, not `ApiResponse<?>`; a constructor with >7 params → use a **Builder**, not a parameter object.
  - **Control flow:** avoid `break`/`continue`/named labels in loops — extract a helper predicate and `return` early; keep methods small (extract helpers) to stay under cognitive-complexity limits; remove unused locals/fields.
  - **Tests:** AssertJ fluent form (`hasSize`, `containsKeys`, `containsEntry`, `hasSameHashCodeAs`, `hasToString`) instead of `.size()`/`.keySet()`/`.hashCode()` intermediates; no `Thread.sleep` or `try { … } catch (…) { fail(…); }` — use **Awaitility**; repeated reject/accept cases → `@ParameterizedTest` + `@ValueSource`; hoist constant / heavy strings (e.g. `"x".repeat(129)`, `URI.create(...)`, `Duration.of(...)`) out of lambdas.
  - **Docker:** pin base images by **digest**, not floating tags (`eclipse-temurin@sha256:…`).
  - **Static analysis:** the project is scanned by SonarQube (rules surface as `java:S<nnn>` / `docker:S<nnn>`). Follow the above proactively so the CI gate stays green without a cleanup pass; fix at the source, never suppress the rule.
