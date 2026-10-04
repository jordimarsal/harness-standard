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

## What gets installed

- **Leader** — orchestrates, stops at the human approval gate.
- **Spec Author** — writes `requirements.md` / `design.md` / `tasks.md`.
- **Implementer** — builds one batch at a time (2–4 tasks: a change plus its
  tests), gates green after every task, tests first.
- **Reviewer** — checks requirement traceability before `done`; runs every
  command itself instead of trusting the implementer's claims.
- Plus `docs/` (specs, architecture, conventions, verification) and `harness/`
  (feature list, checkpoints, progress, logs, gates).

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
       docs/architecture-options.md docs/iteration-protocol.md

# 2. OPTIONAL and destructive — only if this project no longer needs them.
# rm -rf harness docs/architecture.md docs/conventions.md
```
