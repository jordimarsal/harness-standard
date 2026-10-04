# Harness Standard

[![CI](https://github.com/jordimarsal/harness-standard/actions/workflows/ci.yml/badge.svg)](https://github.com/jordimarsal/harness-standard/actions/workflows/ci.yml)

Install a repeatable process for coding agents in one command.

## The problem

Agents drift. They are sharp on one file and lost across a repo. Specs, roles and
gates fix that — but only if they are installed, not just described.

## Install

```bash
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=claude
# or
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=opencode
```

The installer detects your stack, copies the roles, conventions and gates, and
writes `HARNESS.md` into your repo with the next step.

Requires `git`. Non-interactive installs (CI, pipes) skip the prompts and use
defaults: tool `claude`, no optional modules, audit level `basic`.

## Update

Already installed? Re-run the installer with `--update`. It detects the
installed version and tool, re-applies the stored modules and audit level,
and refreshes every harness-managed file while keeping your state
(`harness/feature_list.json`, `harness/progress/`, `harness/specs/`,
`docs/architecture.md`, `docs/conventions.md`):

```bash
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --update
```

Without `--ref`, `--update` fetches the newest `v*` tag (fresh installs stay
pinned to the default version). The installed version is recorded in
`harness/feature_list.json` (`project.harness_version`) and `HARNESS.md`.

## What gets installed

- **Leader** — orchestrates, stops at the human approval gate.
- **Spec Author** — writes `requirements.md` / `design.md` / `tasks.md`.
- **Implementer** — builds one batch at a time (2–4 tasks: a change plus its
  tests), gates green after every task, tests first.
- **Reviewer** — checks requirement traceability before `done`; runs every
  command itself instead of trusting the implementer's claims.
- Plus `docs/` (specs, architecture, conventions, verification) and `harness/`
  (feature list, checkpoints, progress, logs, gates).

## Cost discipline

The harness also keeps sessions cheap — the same model, fewer tokens:

- **Small batches** — implementers get 2–4 tasks per dispatch, never a whole
  feature.
- **Logs on disk** — command output over ~20 lines goes to `harness/logs/`;
  chat keeps the path and a short excerpt.
- **Cheap eyes on big logs** (optional `log-reader` module) — a read-only
  subagent reads the log and returns evidence; every quote is verified
  against the original before it counts.
- **Per-feature retro** — `retro: <n> dispatches · <s> stalls · <r> restarts`
  in `harness/progress/history.md` shows where friction accumulates.

## Optional modules

Add `--modules=a,b` to the install command, or pick them in the interactive
menu:

- `architecture-catalog` — reference catalog of architecture options for design decisions
- `decision-memory` — ADR files for decisions worth remembering beyond a feature
- `iterative-refinement` — adaptive iteration protocol with self-review and adversarial checklist
- `log-reader` — delegate big-log reading to a cheap read-only subagent and verify its evidence
- `performance-benchmarks` — benchmark verification rules and a stack-aware bench runner
- `project-scanner` — deterministic Python project scanner for impact analysis
- `security-audit` — security audit checklist plus SAST and dependency scan tool
- `wekan-tickets` — mirror every workflow state transition on a Wekan kanban board

## This website is built with it

`jordimp.net` is built with this harness. Its own repo is the reference install:
https://jordimp.net

Badge contract: any "built with harness-standard" badge must link
[github.com/jordimarsal/harness-standard](https://github.com/jordimarsal/harness-standard) and use the install string above verbatim.

## Stacks

TypeScript · Node.js · Java · Python · Android · Rust · Generic — 7 stacks.

## Uninstall

```bash
# 1. Remove harness-managed templates (safe: keeps your docs and all harness state).
rm -rf CLAUDE.md AGENTS.md opencode.json .claude .opencode HARNESS.md \
       docs/specs.md docs/verification.md \
       docs/architecture-options.md docs/iteration-protocol.md \
       docs/log-reader-protocol.md

# 2. OPTIONAL and destructive — only if this project no longer needs them.
# rm -rf harness docs/architecture.md docs/conventions.md
```
