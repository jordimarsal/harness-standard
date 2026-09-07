# Expected outcome — 01-traceability-clean

- Tool: `python3 harness/tools/check-traceability.py --feature feat-a --json`
- Exit code: 0
- Verdict: PASS
- Shape: `features[0].requirements == 2`, `covered == 2`, `gaps == []`
