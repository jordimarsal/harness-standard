# Changelog

## v0.2.0 — 2026-10-04

- **Log archiving** (token-cost discipline): command output over ~20 lines
  (tests, builds, failing gates) goes to `harness/logs/<feature>/T<n>.log`;
  chat and progress files keep only the path plus a short excerpt. The
  reviewer reads big logs surgically (`grep -n`, `sed -n`) instead of
  end-to-end; the leader never pastes outputs into dispatch prompts.
- **`log-reader` module** (optional): delegates big-log reading to a cheap
  read-only subagent and verifies its quoted evidence against the original;
  on verification failure it falls back to reading the exact ranges with the
  main model. Installs `docs/log-reader-protocol.md`; leader and reviewer
  pick it up as a conditional capability.
- **README**: new "Cost discipline" and "Optional modules" sections; the
  uninstall snippet now also removes `docs/log-reader-protocol.md`.
- **Version stamp + `--update`**: every install records its harness version in
  `harness/feature_list.json` (`project.harness_version`) and `HARNESS.md`.
  New `--update` mode: detects the installed version and tool, re-applies the
  stored modules and audit level without flags (fixing the `--force` footgun
  that silently dropped them), and refreshes harness-managed files while
  preserving user state. `install.sh --ref=latest` resolves the newest tag;
  `--update` defaults to it. First update-capable release is the one that
  ships this change.
- Fresh installs now default to `v0.2.0` (installer REF pin); `package.json`
  version aligned to the release.
- **Feature retro line**: when a feature closes, the summary moved to
  `harness/progress/history.md` carries `retro: <n> dispatches · <s> stalls ·
  <r> restarts` — the per-feature efficiency record that shows where process
  friction accumulates.
- **Batch discipline** in the subagent prompts: the implementer is dispatched
  **2–4 consecutive tasks per batch** (1 when a single task is large, 4 only for
  small clones, never 5+), never a whole feature. It writes files before any
  prose, runs the quality gates after every task, only then marks `[x]`, and
  answers with one line `done <batch> -> harness/progress/impl_<name>.md`
  pointing at a file that exists (created on the first batch if missing).
- **Leader**: new *implementer batch sizing* table (2–3 default / 1 large / 4
  clones / never 5+), on-disk verification after every batch instead of trusting
  chat claims, stall recovery (`Nothing was written: … Create <first file> now.`)
  and a fresh-session rule once a session nears its context limit — a session
  that fills its context stops working silently and returns nothing.
- **Spec author**: sizes each `T<n>` so batches of 2–4 land green on their own.
- **Reviewer**: states that it executes every command itself, reads test bodies
  (an import-only test covers nothing), and reviews the whole feature in one
  pass — batches are an implementer-side discipline.
- Applied to all four roles in both flavors (`templates/.opencode/agent/` and
  `templates/.claude/agents/`); the installed copies in an existing project
  need the same edit (the installer only writes on install).

## v0.1.1 — 2026-09-24

- Non-interactive installs are silent: with no TTY (curl pipes, CI, `</dev/null`)
  the installer skips all three prompts and uses defaults — tool `claude`,
  no optional modules, audit level `basic`. Pass `--tool=`, `--modules=`,
  `--audit-level=` to choose explicitly. Before this fix a piped install died
  at the first prompt (exit 1) and printed menu theatre into the log.
- `HARNESS_FORCE_TTY=1` forces the interactive prompts (used by the test suite).

## v0.1.0 — 2026-09-22

First public release.

- Remote one-command install:
  `curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=claude`
  (or `--tool=opencode`).
- `--tool=` picks the driver: `claude` (CLAUDE.md + `.claude/`) or `opencode`
  (AGENTS.md + `.opencode/`).
- Requires `git` (the installer clones this repo shallowly).
- Installer detects the stack, copies roles/conventions/gates, writes `HARNESS.md`.
- Four roles (Leader / Spec Author / Implementer / Reviewer) for Claude Code and opencode.
- 7 stacks: TypeScript, Node.js, Java, Python, Android, Rust, Generic.
- Uninstall: `rm -rf CLAUDE.md AGENTS.md opencode.json .claude .opencode harness docs/architecture.md docs/conventions.md docs/specs.md docs/verification.md`
  (see README).
