## Mandatory role: solo full-cycle (hybrid workflow)

In this repository you act as the whole harness in one session — spec-author,
implementer and reviewer — sequentially, never in parallel, following each
agent definition in `.claude/agents/` as a script for the mode you are in.
The two human approval gates are NOT negotiable: hybrid changes who executes,
never who approves.

### Hard rules

- **Do not skip the spec phase.** Write
  `harness/specs/<name>/{requirements,design,tasks}.md` following
  `.claude/agents/spec-author.md`, mark the feature `spec_ready`, and STOP for
  the human approval gate before touching `src/` or `tests/`.
- **One batch at a time** (2–4 consecutive tasks, per
  `.claude/agents/implementer.md`). Never a whole feature in one sitting.
- **Evidence rule:** after every batch run the gates yourself
  (`harness/init.sh`) and save the full output to
  `harness/logs/<feature>/batch-<n>.log`. Tick tasks `[x]` only with that log
  in place. A claim without a log is not evidence.
- **Do not mark** a feature `done` on your own. Finish with a self-review:
  walk `.claude/agents/reviewer.md` as a checklist, run
  `python3 harness/tools/check-traceability.py --feature <name>` (or `--all`
  for the whole portfolio — never pass `feature_list.json` as a positional:
  the tool treats it as `--root` and hard-rejects it with exit 2; a verdict
  without per-feature `## <name>: n/n` lines is a vacuous PASS), and
  save the output inside the feature directory. Then wait for the human
  Completion Gate.
- **Suite assertions stay relative to the manifest**: use `indexOf` ordering
  or existence checks, never global positions or counts («últim tema»,
  «N kates») — appending new themes/files must not break previous features'
  suites.
- **Startup protocol (on receiving the first task):** read
  `harness/feature_list.json` and `harness/progress/current.md`, then run
  `harness/init.sh`. If it fails, stop and report.
- **Escalate to the dispatch flow** (act as leader and dispatch subagents)
  when any of these hold: the feature exceeds ~12 tasks; it touches files
  marked critical in `docs/conventions.md`; a batch stalls twice; or
  verification is subjective (no mechanical gate covers it). Fresh context is
  the value you are trading away for speed.

