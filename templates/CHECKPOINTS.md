# CHECKPOINTS — Final state evaluation

> In multi-agent systems, the destination is evaluated, not the journey.
> These are the objective checkpoints a judge (human or AI) can use
> to decide if the project is healthy.

## C1 — Harness is complete

- [ ] The 4 base files exist: `AGENTS.md`, `init.sh`, `feature_list.json`, `progress/current.md`.
- [ ] The 3 docs exist: `docs/architecture.md`, `docs/conventions.md`, `docs/verification.md`.
- [ ] `./init.sh` finishes with exit code 0.

## C2 — State is coherent

- [ ] At most one feature `in_progress` in `feature_list.json`.
- [ ] Every `done` feature has passing tests.
- [ ] `progress/current.md` is empty or describes the active session (no stale data).

## C3 — Code respects architecture

- [ ] `src/` only contains modules foreseen in `docs/architecture.md`.
- [ ] No debug prints, no context-free TODOs.

## C4 — Verification is real

- [ ] `tests/` has at least one test per `src/` module.
- [ ] All tests pass (`./init.sh` green).

## C5 — Session closed properly

- [ ] No suspicious untracked files.
- [ ] `progress/history.md` has an entry for the last session.
- [ ] The last worked feature reflects its correct state.

## C6 — Spec Driven Development

- [ ] Every feature in `spec_ready`, `in_progress`, or `done` has its `specs/<name>/` folder with 3 files: `requirements.md`, `design.md`, `tasks.md`.
- [ ] `requirements.md` uses strict EARS notation.
- [ ] Every `done` feature has all tasks marked `[x]` in `tasks.md`.
- [ ] Each `R<n>` from `requirements.md` is covered by at least one concrete test in `tests/`.

---

**How to use this file:** a reviewer agent (`.claude/agents/reviewer.md`) walks through each checkbox, marks `[x]` or `[ ]`, and rejects session closure if boxes remain unchecked in C1-C6.
