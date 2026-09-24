# Changelog

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
