## Performance Benchmarks (performance-benchmarks module)

> Appended by the harness `performance-benchmarks` module. Benchmarks are run by
> the reviewer with `bash harness/tools/bench.sh` at `audit_level: strict`. They
> are required when a feature: processes > 1,000 items, involves I/O operations
> (DB, API, file), has concurrency/parallelism concerns, or uses caching or
> memoization.

### Framework per stack

| Stack | Tool | When unavailable |
|---|---|---|
| python | `pytest-benchmark` (mark tests with `@pytest.mark.benchmark`) | `bench.sh` reports record-only |
| typescript / node | `vitest bench` (if configured) | record-only |
| rust | `cargo bench` (if `benches/` configured) | record-only |
| java / android | checklist-only (measure manually if needed) | checklist-only |
| generic | checklist-only | checklist-only |

### Baselines (`harness/baselines.json`)

Starts empty (`{}`). After the first measurement of a function/test, add an entry:

```json
{
  "test_send_email_throughput": {
    "mean_ms": 42.3,
    "thresholds": {
      "mean_ms": { "warning": 1.5, "critical": 2.0 }
    }
  }
}
```

- `mean_ms` is the reference measurement (milliseconds; `mean * 1000` from
  pytest-benchmark).
- Multipliers: exceeding `warning` logs a warning; exceeding `critical` rejects
  approval at `strict`.

### Report (compact — only when benchmarks were required)

```markdown
## Performance Benchmarks
- Scenario: <what was measured>
- Result: <mean/p95 or framework output excerpt>
- vs baseline: ok (<ratio>x) | warning | REGRESSION
```

Without a baseline, `bench.sh` records values and warns; it never blocks.

A transient `harness/.bench-last.json` may be produced by the benchmark run;
delete it before closing the session (it is not user state).
