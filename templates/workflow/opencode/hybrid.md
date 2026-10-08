## 4. Workflow (SDD — hybrid: one in-session agent, same gates)

Same discipline as the full flow, executed by a single in-session agent. Roles
become modes you play sequentially; evidence replaces dispatches. The two human
gates are NOT negotiable — hybrid changes who executes, never who approves.

```
pending → [spec mode] → spec_ready → ⏈ HUMAN → in_progress → [batch mode → verify]×n → ⏈ HUMAN → done
```

1. **Spec mode.** Write `harness/specs/<name>/{requirements,design,tasks.md}`
   exactly as `spec-author` would — follow `.opencode/agent/spec-author.md` as
   a script. Mark the feature `spec_ready` and STOP for the human Spec Gate.
2. **Batch mode.** After approval, implement one batch at a time (2–4
   consecutive `T<n>` tasks), following `.opencode/agent/implementer.md`.
   Never a whole feature in one sitting.
3. **Evidence rule (the core of hybrid).** After every batch:
   - run the gates yourself (`harness/init.sh` / TEST_CMD) and save the full
     output to `harness/logs/<feature>/batch-<n>.log`;
   - tick tasks `[x]` only with that log in place, referencing it in tasks.md;
   - verify on disk: files present, no task done without green gates.
   A claim without a log is not evidence — the rule the leader applies to
   subagents, applied to yourself.
4. **Review mode.** Before requesting the Completion Gate: run
   `python3 harness/tools/check-traceability.py --feature <name>` (or `--all`
   for the whole portfolio — never pass `feature_list.json` as a positional:
   the tool treats it as `--root` and hard-rejects it with exit 2; a verdict
   without per-feature `## <name>: n/n` lines is a vacuous PASS),
   save its output to `harness/specs/<name>/review.md`, and walk
   `.opencode/agent/reviewer.md` as a checklist. Reject your own work if any
   `R<n>` lacks evidence.
   - **Suite assertions stay relative to the manifest**: use `indexOf`
     ordering or existence checks, never global positions or counts
     («últim tema», «N kates») — appending new themes/files must not break
     previous features' suites.
5. **Escalate to the full dispatch flow when any of these hold:** the feature
   has more than ~12 tasks; it touches files marked critical in
   `docs/conventions.md`; a batch stalls twice; or verification is subjective
   (no mechanical gate covers it). Then act as leader and dispatch a real
   reviewer subagent — fresh context is the value you are trading away for
   speed.

Trade-off, stated plainly: hybrid trades independent-context review for
velocity. The evidence logs and the traceability check are what keep that
trade honest.
