<!-- language: TypeScript 5.x (strict) -->
<!-- style -->
- `"strict": true` and no `any` — `unknown` + narrowing instead; satisfy the compiler with types, not assertions.
- `const` by default, pure functions first, `readonly` on inputs; classes only at framework boundaries (controllers, decorators).
- Async via `async/await`; no floating promises (`void` only for deliberate fire-and-forget, commented why).
- Early returns over nested conditionals; extract helpers under the cognitive-complexity budget.
<!-- /style -->
<!-- naming -->
- Files `kebab-case` matching the default export (`policy-service.ts`), types/classes `UpperCamel`, values `lowerCamel`, constants `UPPER_SNAKE`.
- Suffix types by role, not by Hungarian: `PolicyDraft`, `RenewalResult` — no `IPolicy`, no `UserData2`.
- Boolean reads as predicate: `isRenewable`, `hasDebt`.
<!-- /naming -->
<!-- structure -->
- Feature folders (`src/policies/`, `src/billing/`) each owning its routes, service and types; shared kernel under `src/shared/`.
- Public surface of a folder = its `index.ts`; anything else is internal.
- Config via typed `process.env` parsing at startup (zod or equivalent) — never `process.env.X` scattered in code.
<!-- /structure -->
<!-- tests -->
- Vitest (or the stack's runner) with Arrange-Act-Assert; test names state behavior: `rejects expired policy`.
- Mock boundaries (HTTP, clock, db) with the framework's standard tool (`vi.mock`, MSW); no `sleep` — fake timers.
- Table-driven cases via `test.each`; type-level expectations (`expectTypeOf`) for exported APIs.
<!-- /tests -->
<!-- errors -->
- Domain errors extend a base `AppError` with a code; never throw bare strings or `Error('x')` at boundaries.
- Catch only what you handle; rethrow wrapped with context (`throw new PolicyNotFound(id, { cause: err })`).
- Result-style returns (`Result<T, E>`) for expected failures in the domain; exceptions for the unexpected.
<!-- /errors -->
<!-- quality -->
## Code quality

- `eslint` + `tsc --noEmit` are gates: zero warnings policy, `eslint-disable` needs a why-comment and an issue reference.
- Logging via pino (or the stack standard), structured JSON, child loggers per request — never `console.log` in shipped code.
- Dependencies pinned by lockfile; `npm audit` gate in CI; no wildcard ranges added by hand.
<!-- /quality -->
