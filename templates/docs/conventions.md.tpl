# Conventions

This document defines the coding and project conventions for the project. These rules
exist to enforce extreme homogeneity across the codebase. The goal is that any developer
can open any file and immediately understand its structure, naming, and intent without
having to learn a new style.

**Default policy: no comments.** Code must be self-documenting through clear naming and
structure. Comments are permitted only when they explain *why* a non-obvious decision was
made. Comments that describe *what* the code does are prohibited; if the code cannot be
understood without comments, rewrite the code.

---

## Style Rules

{{STYLE_RULES}}

---

## Naming Rules

{{NAMING_RULES}}

---

## File Structure

{{FILE_STRUCTURE}}

---

## Test Rules

{{TEST_RULES}}

---

## Error Handling

{{ERROR_HANDLING}}

---

## Design Principles

Minimum bar for every stack and language — the language sections above may add
rules, never subtract these:

- **Semantic types over loose dictionaries.** Model domain concepts as enums,
  DTOs, value objects, records or dataclasses instead of passing raw
  dictionaries/maps around — the type name carries the meaning.
- **One concept per class, one responsibility per method** (Single
  Responsibility Principle).
- **No nested try/catch.** Extract a named function that handles one failure
  mode instead.
- **Prefer composition over inheritance.**
- **Prefer immutability:** final fields, immutable objects, unmodifiable
  collections — initialize once, never mutate shared state in place.
- **Tell, don't ask.** Behavior lives on the object that owns the data; value
  objects are rich (they validate and act), not anemic data bags.

---

## Commit Rules

Every commit in this repository follows
[Conventional Commits](https://www.conventionalcommits.org/):

- Format: `<type>(<optional scope>)!: <summary>` — e.g. `feat(auth): add refresh-token rotation`.
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `release`, `revert`.
- `!` (or a `BREAKING CHANGE:` footer) marks a breaking change.
- `.git/hooks/commit-msg` (source: `harness/tools/commit-msg`) enforces the
  format on every commit; `--no-verify` is reserved for exceptional cases,
  never a workaround.

---

{{QUALITY_SECTION}}
