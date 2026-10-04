# Design: version stamp and `--update` flow

**Date:** 2026-10-04
**Status:** Approved (maintainer requirement)
**Source:** installed projects had no way to know which harness-standard
version they carry, and no first-class path to a newer one.

## 1. Problem

- The installer writes **no version anywhere** in the target project. Neither
  `feature_list.json` nor `HARNESS.md` records what installed them.
- The only refresh path is `--force`, and it has a footgun: without re-passing
  `--modules`, the stored module set is **silently dropped** (modules default
  to none). `--audit-level` behaves the same way.
- "Which files are harness-managed" is exactly the set the Oct 2 changelog
  note complained about ("the installed copies in an existing project need the
  same edit — the installer only writes on install").

## 2. Decision

**Stamp.** Every install records the installing version:

- `HARNESS_VERSION` resolved at install time: `git describe --tags --always`
  in the templates checkout → fallback: first `## vX.Y.Z` heading in
  `CHANGELOG.md` (skips `Unreleased`) → fallback `dev`.
- Written to `feature_list.json` → `project.harness_version` (schema allows
  extra properties) and to `HARNESS.md`. `refresh_project_metadata` updates
  the stamp on every reinstall, so the stamp always reflects the last run.

**Update.** New `--update` mode in `init.sh` (passed through by `install.sh`):

- Requires an existing harness — the inverse of the install refusal.
- Reads the stored config instead of asking: tool from `CLAUDE.md` vs
  `AGENTS.md`, modules and audit level from `feature_list.json`. Flags
  override; absence never drops anything (fixes the `--force` footgun for
  updates).
- Reports `Updating harness: <old> → <new>` (equal versions → repair run,
  stated as such); `old` is `unknown` for pre-versioning installs.
- Refreshes exactly the `--force` file set (templates, tools, modules,
  CHECKPOINTS) and preserves the same user state (feature_list.json,
  progress/, specs/, docs/architecture.md, docs/conventions.md).

**Refs.** `install.sh` learns `--ref=latest` (resolves the newest `v*` tag via
`git ls-remote`, `sort -V`), and `--update` without an explicit `--ref`
defaults to `latest` — an update that fetches the pinned `v0.1.1` default
would be a no-op by construction. Fresh installs keep the pinned default.

Explicitly kept out: no semver ordering or migration scripts (the report is
informational; templates are declarative files — refreshing them *is* the
migration), no auto-update from inside the leader/agents.

## 3. Verification

- Fresh install stamps a non-empty `harness_version` (tag, tag-distance or
  SHA depending on checkout) in `feature_list.json` and `HARNESS.md`.
- `--update` without a harness is refused.
- `--update` re-applies the stored module set and audit level without flags,
  preserves progress files, and reports the version transition.
- `install.sh --update` bootstraps end-to-end from a local clone
  (`HARNESS_REPO_URL`), as the remote-install test already does.
- Existing suite stays green (the `--force` semantics are unchanged).
