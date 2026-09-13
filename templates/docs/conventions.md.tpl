# Conventions

This document defines the coding and project conventions for the project. These rules
exist to enforce extreme homogeneity across the codebase. The goal is that any developer
can open any file and immediately understand its structure, naming, and intent without
having to learn a new style.

**Default policy: no comments.** Code must be self-documenting through clear naming and
structure. Comments are permitted only when they explain *why* a non-obvious decision was
made. Comments that describe *what* the code does are prohibited; if the code cannot be
understood without comments, rewrite the code.

---

## Style Rules

{{STYLE_RULES}}

---

## Naming Rules

{{NAMING_RULES}}

---

## File Structure

{{FILE_STRUCTURE}}

---

## Test Rules

{{TEST_RULES}}

---

## Error Handling

{{ERROR_HANDLING}}

---

## Code quality (SonarQube)

The project is scanned by SonarQube (IDE rules appear as `java:S<nnn>` / `docker:S<nnn>`). Follow
these conventions proactively so the CI gate stays green without a cleanup pass; fix at the source,
never suppress the rule.

### Logging
- Never use `System.out`/`System.err`. Use the project's SLF4J logger.
- Pass the throwable as the last arg: `LOG.error("msg", e)` — never `LOG.error(e.getMessage())`.
- Defer expensive args: `LOG.info("{}", () -> expensive())` (lambda / `Supplier`), don't precompute the string.
- Keep WARNING-severity messages as `WARN`; reserve `ERROR` for real failures.

### Resources & exceptions
- Wrap every `AutoCloseable` (stores, containers, pools, files) in **try-with-resources**.
  A class-scoped container started in `@BeforeAll`/`@AfterAll` cannot use try-with-resources →
  annotate the owning method with `@SuppressWarnings("resource")` and document why.
- Unused caught exception params → `_` (modern Java): `catch (RuntimeException _)`.
- Empty override methods need a one-line comment explaining why they're empty.

### APIs & data types
- No wildcard return types: return `ApiResponse<Object>`, not `ApiResponse<?>`.
- Prefer `record` for immutable value objects.
- A constructor with >7 params → use a **Builder**, not a parameter object.
- Clamp with `Math.clamp(value, min, max)` (Java 21+), not `Math.max(min, Math.min(value, max))`.

### Control flow & complexity
- Avoid `break`/`continue`/named labels in loops; extract a helper predicate and `return` early.
- Keep methods under the cognitive-complexity budget: extract helpers instead of nesting loops/branches.
- Remove unused locals/fields.

### Tests
- AssertJ fluent form, not `.size()`/`.keySet()`/`.hashCode()` intermediates: `hasSize(n)`,
  `containsKeys(...)`, `containsEntry(k, v)`, `hasSameHashCodeAs(other)`, `hasToString(...)`.
  Chain `assertThat(a).isEqualTo(b).hasSameHashCodeAs(b)`.
- Hoist constant / expensive strings (e.g. `"x".repeat(129)`, `URI.create(...)`, `Duration.of(...)`) out of lambdas.
- No `Thread.sleep` and no `try { … } catch (…) { fail(…); }`: use **Awaitility**
  (`await().during(Duration.ofMillis(n)).until(() -> true)`).
- Repeated reject/accept cases → `@ParameterizedTest` + `@ValueSource`.

### Docker
- Pin base images by **digest**, not floating tags: `eclipse-temurin@sha256:…` (the tag may stay as
  documentation, but the digest is what's enforced).
