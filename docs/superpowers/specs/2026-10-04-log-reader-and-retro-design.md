# Design: log-reader module and feature retro

**Date:** 2026-10-04
**Status:** Approved (roadmap agreed with the maintainer)
**Source material:** NVIDIA/MIT harness-cost work (Karpathy loop applied to
agent harnesses): same LLM, same benchmark — change only the harness, cut
API cost ~2x. Four mechanisms survived their search; this design adopts the
two that a prompt/template repo can own.

## 1. Problem

Two gaps, both consequences of the log-archiving rule (`harness/logs/`,
commit `fcf56f4`):

1. **Big logs now exist on disk — who reads them?** Without a rule, the next
   session reads a thousand-line log end-to-end with the main model, burning
   the exact context the archiving rule saved. The paper's answer: delegate
   log reading to a cheaper model, verify its evidence against the original,
   and fall back to reading the full log only when verification fails.
2. **No efficiency record.** Quality is gated (tests, review, checkpoints),
   but nothing records how much *process friction* a feature cost — stalls,
   re-dispatches, session restarts. The paper's step 1 is "inspect the
   execution logs to find where tokens stop moving the task forward"; the
   harness equivalent is a per-feature retro line in the historical log.

## 2. Decision

Two mechanisms, following the established "light" principle (zero new agent
roles, zero new workflow states — `2026-09-06-harness-modules-design.md` §2):

| # | Mechanism | Form |
|---|---|---|
| 1 | **log-reader module** (optional) | `templates/modules/log-reader/` → installs `docs/log-reader-protocol.md`; leader and reviewer absorb it as a conditional capability |
| 2 | **Feature retro line** (core) | implementer appends `retro: <n> dispatches · <s> stalls · <r> restarts` under the summary it moves to `harness/progress/history.md` |

### Why no new agent template

The point of the reader is to run on a *cheaper model*. Agent definitions
pin a model in frontmatter (Claude Code) while OpenCode allows per-dispatch
model choice — hardcoding either shape would fork the flavors. Instead the
protocol stays runtime-neutral: the dispatcher uses a cheap model **when the
dispatch interface allows it**, and the default model otherwise. The protocol
still pays at equal model cost, because the log never enters the
dispatcher's context.

## 3. Module: log-reader

```
templates/modules/log-reader/
├── manifest.json
└── log-reader-protocol.md     → docs/log-reader-protocol.md (mode: copy)
```

Protocol contract (full text in the file):

- **When:** log bigger than ~200 lines or the need is "where did it fail" —
  under that, `grep -n` / `sed -n` beats a dispatch.
- **Dispatch:** one read-only subagent; prompt carries log path, the
  question, and the evidence format. Nothing else.
- **Evidence format:** per finding — `file`, `lines`, `quote` (≤3 verbatim
  lines), `command` that produced it. No summaries without quotes; no
  recommendations; `not found` instead of speculation.
- **Verification (dispatcher, non-negotiable):** re-run every `command` and
  re-read the cited lines. Any mismatch or invented quote → discard **all**
  the reader's evidence and read the exact ranges with the main model. No
  partial salvage.

Role absorption (conditional, keyed on `docs/log-reader-protocol.md` existing):

- **leader** — dispatches the reader instead of reading big logs in session;
  verifies before acting.
- **reviewer** — may delegate logs over ~200 lines, but evidence it cannot
  re-verify itself is a defect (consistent with "run every command yourself").

## 4. Feature retro line

At closure (implementer protocol step 9, after the human approval record):
the summary moved to `harness/progress/history.md` gains one line:

```
retro: <n> dispatches · <s> stalls · <r> restarts
```

The implementer counts what it received: a stall is a `Nothing was written`
re-dispatch; a restart is being re-dispatched in a fresh session. The leader
and the human read `history.md` to see where friction accumulates — the
input for the paper's keep-or-discard loop on the harness itself.

`templates/progress/history.md` documents the entry shape.

## 5. Out of scope

- **Token/cost telemetry** — owned by the runtime (Claude Code `/cost`,
  OpenCode session stats). The templates cannot see it; the retro line
  records what the agents can count.
- **Eval fixtures with a cost dimension** — needs live agent runs; the
  existing `evals-fixtures/` verify reviewer verdicts deterministically in
  CI. Revisit if a reference task set gets defined.
- **Compaction economics** (the paper's "compact when savings outweigh cache
  rewrite") — compaction is runtime-owned; the leader already has the
  fresh-session-at-batch-boundary rule.

## 6. Verification

- `tests/test-install.sh`: menu lists `log-reader`; manifest validation
  (auto-discovers modules) accepts it; a dedicated install test asserts
  `docs/log-reader-protocol.md` lands and the module is recorded in
  `harness/feature_list.json`.
- Flavor sync: leader/reviewer conditional bullets identical in `.claude`
  and `.opencode` templates (frontmatter differences pre-existing).
- `bash tests/test-install.sh` and `bash tests/test-security.sh` green.
