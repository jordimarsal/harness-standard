# Eval fixtures (frozen corpus)

Deterministic scenarios with known expected outcomes. Consumers: harness-standard's
own test suite, and `harness-graph` phase-4 evals. Fixtures are versioned with the
repo — changing a fixture invalidates historical eval results.

| Fixture | Tool under test | Command | Expected |
|---|---|---|---|
| `01-traceability-clean` | `check-traceability.py` | `--feature feat-a --json` | exit 0, `verdict: PASS` |
| `02-traceability-gap` | `check-traceability.py` | `--feature feat-a --json` | exit 1, `verdict: FAIL`, gap `R2` |
| `03-planted-security-bug` | `audit-security.sh --json` | from `project/` | exit 1, `verdict: REJECT` (requires `bandit` installed) |

Each fixture ships `project/` (a minimal harness layout slice) and `EXPECTED.md`
(the ground truth).
