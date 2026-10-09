# Harness Standard

[![CI](https://github.com/jordimarsal/harness-standard/actions/workflows/ci.yml/badge.svg)](https://github.com/jordimarsal/harness-standard/actions/workflows/ci.yml)
[![Quality Gate](docs/images/badge-quality-gate.svg)](https://jordimarsal.github.io/harness-standard/)
[![Code Smells](docs/images/badge-code-smells.svg)](https://jordimarsal.github.io/harness-standard/)
[![built with harness-standard](assets/badge.svg)](https://github.com/jordimarsal/harness-standard)

Install a repeatable process for coding agents in one command.

## The problem

Agents drift. They are sharp on one file and lost across a repo. Specs, roles and
gates fix that — but only if they are installed, not just described.

## Install

```bash
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=claude
# or
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=opencode
# solo repo, same gates, one in-session agent (reviewer becomes an
# evidence-logged self-review; escalate for risky features):
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=opencode --hybrid
```

The installer detects your stack, copies the roles, conventions and gates, and
writes `HARNESS.md` into your repo with the next step. `--hybrid` (or
`--workflow=full|hybrid`) selects how features execute — full dispatches
spec-author/implementer/reviewer subagents; hybrid runs the same SDD flow and
human gates in one session, with mandatory evidence logs. The choice is stored
in `harness/feature_list.json` and `--update` keeps it.

Python projects use **uv** by default: test/build commands are rendered as
`uv run pytest tests` / `uv build`. Pass `--no-uv` to keep plain
`python3 -m pytest` commands (re-pass it on `--update` — commands are
re-detected on every run), or install uv and the next update picks it up.

## Conventional Commits

Every install — any tool, any workflow, `--hybrid` included — enforces
[Conventional Commits](https://www.conventionalcommits.org/) in your
repository. The installer wires a `commit-msg` hook
(`.git/hooks/commit-msg`, source: `harness/tools/commit-msg`) that **rejects
any commit whose subject does not follow the format**. Write commits like:

```text
feat(auth): add refresh-token rotation
fix(parser): handle empty payloads
chore!: drop Node 18 support
```

- Format: `<type>(<optional scope>)!: <summary>` — `!` (or a
  `BREAKING CHANGE:` footer) marks a breaking change.
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
  `ci`, `chore`, `release`, `revert`.
- `Merge …` and `Revert …` subjects bypass the check.
- `--no-verify` exists for exceptional cases; it is not a way around the rule —
  the agents are held to the same standard by the entry-file hard rules and
  `docs/conventions.md`.
- Not a git repository? The hook is skipped and the rule stays documented.
- A `commit-msg` hook you installed yourself is never overwritten — keep it
  and chain `harness/tools/commit-msg` to add the check.

Project-specific additions to the entry file (`CLAUDE.md` / `AGENTS.md`) go
inside the `harness:project` block at the end of the file: the installer
preserves that block verbatim across `--update`/`--force` and never counts it
as a customization, so routine updates create no backup noise.

Requires `git`. Non-interactive installs (CI, pipes) skip the prompts and use
defaults: tool `claude`, no optional modules, audit level `basic`.

Pick the architecture up front with `--architecture=hexagonal` (or `layered`,
`clean`, `cqrs`, `microservices`, `modular-monolith`, `event-driven`) — or
choose from the menu on an interactive terminal; otherwise a generic template
is installed. On a TTY the installer also asks.

## Existing files: collision backup

Installing into a project that already has an `AGENTS.md` (Codex, Cursor, …),
`docs/specs.md` or any other file the harness would write? The installer never
silently overwrites: it lists the colliding files and, on a TTY, asks whether
to move them aside. Answering `y` (or passing `--backup`) moves them — never
deletes — to `harness/backup/<UTC>/` preserving their relative paths:

```bash
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=opencode --backup
# or choose where they land:
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=opencode --backup=~/old-config
```

Non-interactive installs (CI, pipes) abort with the collision list unless
`--backup` is given. Detection is tool-aware: an existing `AGENTS.md` does not
collide with a claude install (`CLAUDE.md` is the entry file there), so it is
left untouched. After the install, the summary lists everything that was
backed up — review it and merge back what you need.

## Update

Already installed? Re-run the installer with `--update`. It detects the
installed version and tool, re-applies the stored modules and audit level,
and refreshes every harness-managed file while keeping your state
(`harness/feature_list.json`, `harness/progress/`, `harness/specs/`,
`docs/architecture.md`, `docs/conventions.md`). Replaced files that you
customized (they differ from the templates) are backed up to
`harness/backup/<UTC>/` first — an untouched project creates no backup noise:

```bash
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --update
```

Without `--ref`, `--update` fetches the newest `v*` tag (fresh installs stay
pinned to the default version). The installed version is recorded in
`harness/feature_list.json` (`project.harness_version`) and `HARNESS.md`.

Evolve an installed project without retyping anything:

```bash
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --update --add-modules=security-audit
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --update --remove-modules=security-audit
curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --update --architecture=hexagonal
```

`--add-modules` / `--remove-modules` work at any time — added modules install
their files, removed ones have their files and injected sections stripped.
`--architecture` switches the architecture template; your own edits to
`docs/architecture.md` / `docs/conventions.md` are preserved (only the marked
architecture section is refreshed). Conventions and architecture docs are
otherwise regenerated on update only when they are still installer-generated;
anything you edited is left untouched.

## What gets installed

- **Leader** — orchestrates, stops at the human approval gate.
- **Spec Author** — writes `requirements.md` / `design.md` / `tasks.md`.
- **Implementer** — builds one batch at a time (2–4 tasks: a change plus its
  tests), gates green after every task, tests first.
- **Reviewer** — checks requirement traceability before `done`; runs every
  command itself instead of trusting the implementer's claims.
- Plus `docs/` (specs, architecture, conventions — generated for your stack
  and chosen architecture, verification) and `harness/`
  (feature list, checkpoints, progress, logs, gates).

`docs/conventions.md` ships a stack-agnostic minimum bar in every install
(semantic types over loose dictionaries, SRP, no nested try/catch, composition
over inheritance, immutability, tell-don't-ask) plus the Conventional Commits
commit rules.

## Quality

Analyzed with SonarQube behind a custom quality gate ("Viatgecio Way") — current
metrics and the raw `harness-report.json` live on the
[quality page](https://jordimarsal.github.io/harness-standard/), published on
GitHub Pages. There is deliberately no coverage number: the runtime suites are
bash e2e install/security tests (`npm test`) and the Python tools in
`templates/` are verified against the frozen `evals-fixtures/` corpus. After
each scan, refresh the published assets with:

```bash
python3 scripts/sonar-quality.py   # reads ../harness-report.json, renders page + badges
```

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
- `clarity` — 80% ASD-STE100 response style: short active sentences, one term one meaning, no filler
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

## Badge

The brand badge ships in two variants: `assets/badge.svg` (dark — traffic
lights, prompt green on near-black) and `assets/badge-light.svg` (warm light —
for light-themed sites). Sites that toggle themes swap them by CSS.

In a GitHub README of a project built with the harness:

```markdown
[![built with harness-standard](assets/badge.svg)](https://github.com/jordimarsal/harness-standard)
```

From a different repository, use the raw URL:

```markdown
[![built with harness-standard](https://raw.githubusercontent.com/jordimarsal/harness-standard/main/assets/badge.svg)](https://github.com/jordimarsal/harness-standard)
```

On a website (e.g. a footer), copy the SVGs into the site — first-party, no
hotlinking — and wrap them in the same link. Theme-adaptive pattern:

```html
<a href="https://github.com/jordimarsal/harness-standard" rel="noopener">
  <img src="/assets/badge-light.svg" alt="built with harness-standard"
       width="210" height="20" class="badge-light">
  <img src="/assets/badge.svg" alt="" aria-hidden="true"
       width="210" height="20" class="badge-dark">
</a>
<style>
  .badge-dark { display: none; }
  @media (prefers-color-scheme: dark) {
    .badge-light { display: none; }
    .badge-dark { display: inline; }
  }
</style>
```

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

## Releasing

Maintainer-facing: how a version ships.

1. Move the `Unreleased` section of `CHANGELOG.md` under a `## vX.Y.Z — date`
   heading.
2. Bump the installer REF pin in `install.sh` and the version in
   `package.json`; commit as `chore(release): vX.Y.Z` and push.
3. Tag and push the tag:
   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z — one-line summary" && git push origin vX.Y.Z
   ```
4. Publish the GitHub release with the CHANGELOG section as notes:
   ```bash
   awk -v ver="vX.Y.Z" '$0 ~ "^## "ver {f=1; next} /^## / && f {exit} f' \
     CHANGELOG.md > /tmp/notes.md
   gh release create vX.Y.Z --verify-tag --latest \
     --title "vX.Y.Z — one-line summary" --notes-file /tmp/notes.md
   ```

A pushed tag alone is not visible on the Releases page — step 4 is what
publishes it. `--ref=latest` and `--update` resolve tags either way.
