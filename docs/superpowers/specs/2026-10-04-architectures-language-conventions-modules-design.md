# Design: architectures, per-language conventions, add/remove modules

**Date:** 2026-10-04
**Status:** Approved (maintainer requirement)
**Source:** three needs: add optional modules at any time, choose an
architecture into `docs/architecture.md` + `docs/conventions.md`, and
per-language conventions (the current "common" template is Java in disguise).

## 1. Problem

- `docs/conventions.md.tpl` ships Java rules (SLF4J, AssertJ, records,
  Awaitility) as "common" conventions — wrong for 6 of 7 stacks.
- Architecture choice is reference-only: the catalog module informs `design.md`
  but nothing lands in `docs/architecture.md` / `docs/conventions.md`.
- Modules are chosen once, at install. `--update` re-applies the stored set;
  changing it means re-typing the whole list, and nothing removes an
  uninstalled module's injected files.

## 2. Decision

### Per-language conventions (composable, no include machinery)

- `templates/docs/conventions.md.tpl` stays the single frame; placeholders
  `{{STYLE_RULES}} {{NAMING_RULES}} {{FILE_STRUCTURE}} {{TEST_RULES}}
  {{ERROR_HANDLING}}` plus new `{{QUALITY_SECTION}}` (the Sonar block moves
  out of the frame — it was Java).
- New `templates/conventions/<stack>.md` (7 files) with marker-delimited
  chunks (`<!-- style -->` … `<!-- /style -->`, likewise naming, structure,
  tests, errors, quality). `generic` = the old "define here" guidance.
- Assembly (init.sh): extract chunks, sed into frame. Fresh installs always
  generate from the detected stack; `generic` falls back to the old tpl
  semantics.

### Architectures as selectable templates

- `templates/architectures/<name>/` — the directory IS the selection list
  (like modules). Seven, matching the catalog's core patterns: `layered`,
  `hexagonal`, `clean`, `cqrs`, `microservices`, `modular-monolith`,
  `event-driven`.
- Each dir: `architecture.md` (full document: principles, data flow, do-not)
  and `conventions-section.md` (architecture-specific conventions block).
- `--architecture=<name>` at install or update (interactive picker at fresh
  install on a TTY; updates are flags-only, so automated `curl|bash` runs never
  block on a menu; invalid name fails listing the available set). It rewrites
  `docs/architecture.md` from the template and injects the conventions
  section into `docs/conventions.md` between
  `<!-- harness:module:architecture:start/end -->` markers (same idempotent
  machinery as module sections). The choice is recorded in
  `project.architecture` so later updates regenerate consistently.
- User-state safety: without `--architecture`, an existing
  `docs/conventions.md` / `docs/architecture.md` is regenerated **only if it
  is byte-identical to what the installer would generate, or still carries
  the old placeholder defaults** (installer-owned content self-heals across
  versions); a customized file is left untouched with an info line.

### Modules at any time

- `--update --add-modules=a,b` → stored ∪ added; `--remove-modules=a,b` →
  stored − removed. Both rewrite `project.modules` via the existing refresh.
- Removal also un-installs: manifest-driven — `copy`/`copy-if-missing` targets
  are deleted, `append-section` blocks stripped by their markers, C7 audit
  checkpoint stripped when no audit module remains. Missing manifests (module
  gone upstream) → warn and continue.

## 3. Out of scope

- Architecture-specific `tasks.md`/`design.md` scaffolding — the spec flow
  already owns those.
- Removing architectures (drop the dir in a release; the list is the dirs).
- Interactive module add/remove on update under TTY — flags only for now.

## 4. Verification

- Fresh install: `docs/conventions.md` contains the stack's language chunk
  (e.g. `pytest` on python) and no Java-only rules on other stacks.
- `--architecture=hexagonal` renders `docs/architecture.md` with its
  dependency rule and injects the conventions section exactly once
  (idempotent under repeat runs).
- Update on a generated (unmodified) `docs/conventions.md` refreshes it;
  after a user edit it is left untouched.
- `--add-modules` keeps stored modules and records the union;
  `--remove-modules` deletes copied files, strips marked sections, and
  updates `project.modules`.
- Invalid `--architecture` value is rejected listing the seven.
