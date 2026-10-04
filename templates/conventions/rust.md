<!-- language: Rust (2021 edition) -->
<!-- style -->
- `cargo fmt` and `cargo clippy -- -D warnings` are the baseline; exceptions via `#[allow]` need a why-comment.
- Model the domain in types: newtypes over primitives, enums for closed sets, `non_exhaustive` at public boundaries.
- Prefer borrowing over cloning; `clone()` in hot paths needs a comment justifying it.
- `unsafe` is banned unless proven necessary — isolated in a dedicated module, documented with invariants, fuzzed.
<!-- /style -->
<!-- naming -->
- `snake_case` for functions/fields/modules, `UpperCamel` for types/traits, `SCREAMING_SNAKE` for consts; `C-` conventions of the API guidelines.
- Getters are bare (`policy.holder()`), not `get_holder`; conversions `from`/`into`/`as_`/`to_` per std convention.
- Names state intent: `renewal_queue`, not `rq`.
<!-- /naming -->
<!-- structure -->
- Cargo workspace for multi-crate projects: one crate per deployable/bounded context, `core` crate with no I/O dependencies.
- `src/lib.rs` exposes a deliberate public API (`pub use`); everything else `pub(crate)`.
- Feature flags (`[features]`) compile-independent: default build works without optional integrations.
<!-- /structure -->
<!-- tests -->
- Unit tests in `#[cfg(test)]` modules next to the code; integration tests in `tests/` per public crate.
- `cargo test` plus `cargo clippy` and `cargo fmt --check` in CI; `cargo deny` for licenses/advisories.
- Property tests (proptest/quickcheck) for parsers and invariants; table-driven cases via `#[test_case]`.
<!-- /tests -->
<!-- errors -->
- Libraries: concrete error enums implementing `std::error::Error` (thiserror); apps: a top error type with context (anyhow).
- No `unwrap()`/`expect()` outside tests and `const` contexts; each one in production code needs a proof comment of infeasibility.
- Fallible public APIs return `Result<T, E>` with a documented error enum — never `Option` for "why did it fail".
<!-- /errors -->
<!-- quality -->
## Code quality

- Zero-warning policy across `rustc`, `clippy` (all linters, `-D warnings`) and `rustdoc` (missing docs on public items).
- Logging via `tracing` with spans; structured fields over formatted strings; no `println!` in library crates.
- MSRV declared in `Cargo.toml` and honored by CI; lockfile committed for apps, checked for libs.
<!-- /quality -->
