# Changelog

## v0.5.0 — 2026-10-06

- **Collision backup (`--backup[=DIR]`)**: installing into a project that
  already owns files the harness would write (`AGENTS.md`, `CLAUDE.md`,
  `opencode.json`, `.claude/settings.json`, `docs/specs.md`,
  `docs/verification.md`, `HARNESS.md`, agents dirs, module copies) no longer
  hard-refuses or silently clobbers. The installer lists the collisions and,
  on a TTY, asks to move them aside; non-interactive installs require
  `--backup`. Colliding files are **moved — never deleted —** to
  `harness/backup/<UTC>/` preserving their relative paths, and the install
  summary lists them for manual merge-back. Detection is tool-aware (an
  existing `AGENTS.md` does not collide with a claude install).
  `--force`/`--update` now back up replaced files that differ from the
  templates instead of `rm -f`-ing them (closes the destructive gap on
  customized entry files, configs and agent roles; an untouched project
  creates no backup noise), and a tool switch still cleans the previous
  tool's files. The refusal check is now `harness/`-only; foreign
  `.claude/`/`.opencode/` content no longer blocks a fresh install.
- Fresh installs now default to `v0.5.0` (installer REF pin); `package.json`
  version aligned to the release.

## v0.4.1 — 2026-10-06

- **README badge suggestion**: on success, the installer prints the
  canonical raw-URL badge snippet only when `README.md` exists without a
  "built with harness-standard" badge — and never writes into the file
  (README is user-owned). Idempotent across `--update`: once the badge is
  added, no re-suggestion. No README, no suggestion.
- Fresh installs now default to `v0.4.1` (installer REF pin); `package.json`
  version aligned to the release.

## v0.4.0 — 2026-10-06

- **`clarity` module** (optional): 80% ASD-STE100 response style —
  short active sentences, one term one meaning, no filler. Installs
  `docs/clarity-style.md`. References: Karpathy 2026-10-02
  (`https://x.com/karpathy/status/2105819303471976479`) and Kun Chen
  reply 2026-10-02
  (`https://x.com/kunchenguid/status/2105931853815296295`). Subset
  mined from the last 10 local opencode sessions.
- **Brand badge**: terminal-style SVG asset (`assets/badge.svg`, 210x20 —
  traffic lights + `built with | harness-standard` in prompt green on
  near-black, mono type) plus a light-theme variant (`assets/badge-light.svg`,
  warm paper segments and darker signal greens for contrast). README
  documents canonical usage and the theme-adaptive swap pattern.
- **uv-managed Python + polyglot gates**: `init-verify.sh` runs pytest
  through `uv` when `pyproject.toml` + `uv.lock` exist and runs the
  `web/` subproject suite alongside the root one; the Python-stack
  `TEST_CMD` in `opencode.json` follows the same detection.
- **`check-traceability` fixes**: identifiers containing `::` are exact
  node ids (`tests/path/file.py::test_name`) instead of silently gapping;
  `--all` skips features whose status is not `done` (no impl table yet is
  not a gap).
- **Lint-clean tools**: `validate-feature-list.py` and
  `check-traceability.py` pass a strict ruff config (line-length 100,
  isort) so refreshed projects keep their quality gates green.
- **Templates**: batching hard rule, one-batch-at-a-time workflow step and
  §4 Batching subsection in `AGENTS.md`; *size for batches* rule in
  `docs/specs.md`; two reviewer anti-patterns in `docs/verification.md`
  (trusting a subagent's "done" claim; reading the test count under
  `addopts='-q'`). Upstreamed from real usage (tenda).
- **README**: new maintainer-facing "Releasing" section — the four-step
  release ritual (CHANGELOG heading, REF/package.json bump + commit, annotated
  tag, `gh release create` from the CHANGELOG section). A pushed tag alone
  never shows on the Releases page.
- Fresh installs now default to `v0.4.0` (installer REF pin); `package.json`
  version aligned to the release.

## v0.3.0 — 2026-10-04

- **Per-language conventions**: `docs/conventions.md` is now assembled from the
  detected stack's language conventions (java, python, typescript, node,
  android, rust, generic) — the old frame shipped Java rules to every stack.
  The universal frame stays single-source; language sections are
  marker-delimited chunks.
- **Selectable architectures**: `--architecture=<name>` (layered, hexagonal,
  clean, cqrs, microservices, modular-monolith, event-driven — the directory
  is the catalog) renders `docs/architecture.md` and injects an
  architecture conventions section into `docs/conventions.md`; recorded in
  `project.architecture`. Interactive picker at fresh install on a TTY.
  Installer-generated docs self-heal on update; edited docs are untouched.
- **Modules at any time**: `--update --add-modules=a,b` and
  `--update --remove-modules=a,b` — removal deletes copied files, strips
  marked sections (including the C7 audit checkpoint when no audit module
  remains) and updates `project.modules`. Spec:
  `docs/superpowers/specs/2026-10-04-architectures-language-conventions-modules-design.md`.
- Fresh installs now default to `v0.3.0` (installer REF pin); `package.json`
  version aligned to the release.

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
