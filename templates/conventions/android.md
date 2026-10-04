<!-- language: Kotlin (Android) -->
<!-- style -->
- Kotlin idioms first: `val` by default, data classes for value objects, sealed types for closed hierarchies (UI state, results).
- Coroutines + Flow for async; suspend functions in repositories, `StateFlow` to the UI — never `GlobalScope`, never blocking calls on the main thread.
- Null-safety over defensiveness: no `!!`; `require`/`check` for invariants, `?`-chains at the edges.
<!-- /style -->
<!-- naming -->
- Resources and ids `snake_case` (`activity_policy.xml`, `@+id/submit_button`), code `lowerCamel`, classes `UpperCamel`, constants `UPPER_SNAKE`.
- Layout files named after what they render (`item_policy.xml`, `fragment_billing.xml`), not after their activity.
- ViewModels end in `ViewModel`, repository interfaces in `Repository`, use cases verb-first (`ObservePolicies`).
<!-- /naming -->
<!-- structure -->
- Feature packages (`feature/policies/`, `feature/billing/`) owning screen, viewModel, navigation; `core/` holds shared data and design system.
- Single-activity + Navigation Compose (or Fragments); DI via Hilt; no service-locator singletons.
- Resource strings and dimensions in `strings.xml`/`dimens.xml` — never hardcoded in composables/layouts.
<!-- /structure -->
<!-- tests -->
- Unit tests (JUnit + Turbine for Flows) for ViewModels/use cases; instrumented tests (Espresso/Compose) only for critical journeys.
- Dispatchers injected (`Dispatchers.setMain` in setup) — production code never hardcodes `Dispatchers.Main`.
- Screenshots/visual checks out of unit scope; keep the unit suite hermetic (no emulator, no network).
<!-- /tests -->
<!-- errors -->
- Domain layer models failures as sealed types (`Result`/`Either` style); the UI maps them to messages, never crashes on expected failures.
- Catch narrowly at the edge (ViewModel `runCatching` around use-case calls); log with Timber, tag per feature.
- Never swallow CancellationException — rethrow it.
<!-- /errors -->
<!-- quality -->
## Code quality

- `ktlint` + Android Lint are gates; `detekt` thresholds for complexity; no baseline file to hide new issues.
- Minify + resource shrinking on release builds; `release` builds must pass on every merge to main.
- ProGuard/R8 rules versioned and commented; dependency versions in a version catalog (`libs.versions.toml`).
<!-- /quality -->
