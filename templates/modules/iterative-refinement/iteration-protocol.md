# Iteration Protocol (Adaptive)

> Installed by the harness `iterative-refinement` module. The implementer follows
> this protocol when implementing a feature; the reviewer uses its adversarial
> checklist. Scale the loop depth to feature size — do not run full rounds on a
> one-file change.

## Choose the loop depth (aligned with the leader's effort scaling table)

| Feature size | Loop |
|---|---|
| Trivial (1 file) | Single pass: implement → verify → report |
| Medium (2-3 files) | One refinement round: implement → self-review → fix → verify |
| Complex / very complex | Full rounds below |

## Full rounds (complex features)

### Round 1 — Initial implementation
Produce a complete, working implementation with tests. Note assumptions,
trade-offs, and known limitations in the iteration report.

### Round 2 — Self-review
Apply the quality checklist below. Identify 3-5 concrete improvement areas, fix
them, and document what changed and why.

### Round 3 — Adversarial review (reviewer)
The reviewer challenges the implementation with the adversarial checklist below.
Every finding is either fixed or explicitly defended with rationale in the review
file. The reviewer is a separate agent — self-review never substitutes for it.

### Round 4 — Verification deep dive
Run the real verification commands (never "mentally"):

- Coverage: `python3 -m pytest -q tests --cov=<pkg> --cov-report=term-missing`
  (stack equivalents: `vitest --coverage`, `cargo llvm-cov`, `mvn jacoco:report`).
- Lint and types: `ruff check .` + `mypy --check-untyped-defs .` (stack equivalents:
  `eslint`, `cargo clippy`, `checkstyle/spotbugs`).
- Add tests for untested branches, error paths, and edge cases.

Default coverage targets: 100% domain models, >= 90% services, >= 80% adapters.
Projects override these in `docs/verification.md`; this module never edits that
file.

### Round 5 — Final refinement
Performance, readability, documentation. Re-run the stack quality gates. Only
then request review.

## Adversarial checklist (reviewer)

1. Security: what if a malicious actor provides this input?
2. Performance: what happens with 10,000 concurrent requests?
3. Maintainability: will a junior developer understand this in 6 months?
4. Edge cases: null, empty, negative, unexpected values?
5. Concurrency: is this threadsafe? Any race conditions?
6. Dependencies: could we reduce external dependencies?
7. Testing: is this test brittle? Does it depend on implementation details?

Each finding → fix the code OR document the decision with rationale.

## Quality self-review checklist (implementer, after each round)

1. Architecture decision made and justified (if the feature has one).
2. SOLID principles applied where they reduce, not add, complexity.
3. Type hints / static types pass the stack checker.
4. Dataclasses/Enums/value objects over raw dicts.
5. No blanket `except Exception:`; specific errors raised and caught.
6. Logs use lazy formatting; no secrets in logs.
7. Tests cover happy path, edge cases, and error cases.
8. Test names in English, describing behavior.
9. I/O at the edges; core logic pure.
10. No circular imports; no global state.
11. No nested functions unless closing over a local value.
12. No debug prints, no context-free TODOs.

## Iteration report (appended to `harness/progress/current.md`)

```markdown
## Iteration #N — <phase>
- Changes made: <concrete list>
- Verification: <commands run + result summary>
- Checklist: 12/12 verified (or list the exceptions with reasons)
- Remaining concerns: <for the next iteration or the reviewer>
```
