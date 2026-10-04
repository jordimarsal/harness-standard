# Harness Standard

[![CI](https://github.com/jordimarsal/harness-standard/actions/workflows/ci.yml/badge.svg)](https://github.com/jordimarsal/harness-standard/actions/workflows/ci.yml)
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
```

The installer detects your stack, copies the roles, conventions and gates, and
writes `HARNESS.md` into your repo with the next step.

Requires `git`. Non-interactive installs (CI, pipes) skip the prompts and use
defaults: tool `claude`, no optional modules, audit level `basic`.

Pick the architecture up front with `--architecture=hexagonal` (or `layered`,
`clean`, `cqrs`, `microservices`, `modular-monolith`, `event-driven`) — or
choose from the menu on an interactive terminal; otherwise a generic template
is installed. On a TTY the installer also asks.

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
