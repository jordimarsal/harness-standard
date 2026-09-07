# Expected outcome — 02-traceability-gap

- Tool: `python3 harness/tools/check-traceability.py --feature feat-a --json`
- Exit code: 1
- Verdict: FAIL
- Shape: `features[0].gaps` contains an entry with `requirement == "R2"` (R2 absent
  from the impl table).
