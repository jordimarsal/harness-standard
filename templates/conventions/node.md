<!-- language: Node.js (JavaScript ESM) -->
<!-- style -->
- ESM (`"type": "module"`), `const` by default, pure functions first; no classes outside framework boundaries.
- `async/await` only — no mixed callbacks/promises; every promise awaited or explicitly `void`-discarded with a why.
- Input validation at the boundary (zod or equivalent), plain objects inside; early returns over nesting.
<!-- /style -->
<!-- naming -->
- Files `kebab-case` matching their default export; directories named after the feature they own.
- Functions `lowerCamel` verb-first (`loadPolicy`, `renderInvoice`); constants `UPPER_SNAKE`; booleans read as predicates.
- No abbreviations that need a legend: `repository`, not `repo2`; `maximumRetries`, not `maxR`.
<!-- /naming -->
<!-- structure -->
- Feature folders under `src/` (`src/policies/`, `src/http/`), shared kernel in `src/shared/`; entry point is a thin `src/main.js`.
- Config parsed once at startup into a typed/frozen object; nothing reads `process.env` outside that module.
- Routes → services → repositories, dependencies injected as arguments (no service-locator imports mid-file).
<!-- /structure -->
<!-- tests -->
- The stack's runner (`node:test` or vitest) with behavior-stating names: `rejects an expired policy`.
- Mock the boundaries (http, clock, db); use fake timers instead of `sleep`.
- Table-driven via `test.each` / `it.each`; cover error paths with the same rigor as happy paths.
<!-- /tests -->
<!-- errors -->
- Domain errors extend a base `AppError` carrying a machine code; never throw strings.
- Handle at the edge (route/error middleware), log once with context, respond problem+json — no double handling.
- Operational failures (network, timeout) are retried with backoff explicitly, never in a silent loop.
<!-- /errors -->
<!-- quality -->
## Code quality

- `eslint` (flat config) zero-warnings gate; `npm audit` gate in CI; dependencies pinned via lockfile only.
- Logging via pino, structured JSON with request-scoped child loggers; `console.log` is banned in shipped code.
- Graceful shutdown: close servers and connections on SIGTERM; health checks separate readiness from liveness.
<!-- /quality -->
