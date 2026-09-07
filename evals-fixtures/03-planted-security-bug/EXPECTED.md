# Expected outcome — 03-planted-security-bug

- Tool: `bash harness/tools/audit-security.sh --json` (run from `project/`, python stack)
- Exit code: 1
- Verdict: REJECT
- Requires: `bandit` installed (findings include a HIGH from `src/core/db.py`).
  Without bandit the run degrades to `skipped: ["bandit: not installed"]` and
  verdict PASS — consumers must assert findings, not only the verdict, when
  bandit is available.
- Planted defect: SQL string concatenation + hardcoded credential in
  `src/core/db.py` (bandit B608 / B105 territory).
