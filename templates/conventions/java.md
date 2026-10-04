<!-- language: Java 21+ -->
<!-- style -->
- Apply SOLID and Clean Code daily; prefer immutability (`record` for value objects, `List.of`/`Map.of` factories).
- Constructor with >7 params → **Builder**, not a telescoping parameter list.
- No wildcard return types: return `ApiResponse<Object>`, not `ApiResponse<?>`.
- Avoid `break`/`continue`/labels in loops; extract a helper predicate and return early.
- Keep methods under the cognitive-complexity budget: extract helpers instead of nesting loops/branches.
<!-- /style -->
<!-- naming -->
- Classes `UpperCamel`, methods and fields `lowerCamel`, constants `UPPER_SNAKE`, packages all-lowercase.
- Names state intent, not type: `approvedOrders`, not `orderList2`. Booleans read as predicates: `isRenewable`, `hasDebt`.
- One concept, one name across layers: a `Policy` is `Policy` in API, domain and persistence (map at the edge if shapes differ).
<!-- /naming -->
<!-- structure -->
- Maven/Gradle standard layout: `src/main/java`, `src/test/java`; resources under `src/main/resources`.
- Package by feature first (`policy/`, `billing/`), by layer inside; the domain package never imports Spring, JPA or Jackson types.
- One public class per file; the file name is the class name.
<!-- /structure -->
<!-- tests -->
- JUnit 5 + AssertJ fluent form: `hasSize(n)`, `containsKeys(...)`, `hasSameHashCodeAs(other)` — never `.size()`/`.keySet()` intermediates.
- Rejected/accepted cases → `@ParameterizedTest` + `@ValueSource`/`@EnumSource`.
- No `Thread.sleep`, no `try { … } catch { fail(); }` → Awaitility: `await().during(Duration.ofMillis(n)).until(...)`.
- Infrastructure (DB, Kafka) through **Testcontainers**; hoist expensive constants out of lambdas.
<!-- /tests -->
<!-- errors -->
- Specific exceptions with intent-revealing names (`PolicyNotFoundException`); never catch bare `Exception`/`Throwable`.
- Wrap every `AutoCloseable` in try-with-resources; an `@BeforeAll`-scoped container gets `@SuppressWarnings("resource")` and a why-comment.
- Unused caught exception parameter → `_`: `catch (RuntimeException _)`.
<!-- /errors -->
<!-- quality -->
## Code quality (SonarQube)

The project is scanned by SonarQube (IDE rules appear as `java:S<nnn>`). Follow these rules
proactively so the CI gate stays green without a cleanup pass; fix at the source, never
suppress the rule.

### Logging
- Never `System.out`/`System.err`. Use the project's SLF4J logger.
- Pass the throwable as last arg: `LOG.error("msg", e)` — never `LOG.error(e.getMessage())`.
- Defer expensive args: `LOG.info("{}", () -> expensive())`; keep WARN-severity messages as `WARN`.

### Resources & APIs
- Pin Docker base images by **digest**, not floating tags (`eclipse-temurin@sha256:…`).
- Clamp with `Math.clamp(value, min, max)` (Java 21+), not nested `Math.max`/`Math.min`.
- Remove unused locals/fields; empty overrides need a one-line why-comment.
<!-- /quality -->
