<!-- language: Python 3.12+ -->
<!-- style -->
- PEP 8 enforced by `ruff format` + `ruff check`; line length 100.
- Type hints everywhere (`mypy --strict` clean); `from __future__ import annotations` in modules with cross-references.
- Dataclasses (frozen where possible) for value objects; no mutable default arguments, ever.
- Prefer composition and small pure functions; a module is importable without side effects.
<!-- /style -->
<!-- naming -->
- Modules and packages `snake_case`, classes `UpperCamel`, constants `UPPER_SNAKE`.
- Private-by-underscore (`_internal`) only at package boundaries, not as a decorum habit.
- Test names state the behavior: `test_expired_policy_is_rejected`, not `test_policy3`.
<!-- /naming -->
<!-- structure -->
- `src/` layout (`src/<pkg>/`, `tests/`), never a flat script pile; pyproject.toml is the single build/dependency source.
- Tooling goes through **uv** by default: `uv add` / `uv remove` for dependencies, `uv sync` to materialize the locked venv, `uv run` to execute inside it; commit `uv.lock`.
- Package by feature (`policies/`, `billing/`); `__init__.py` stays empty unless exporting a deliberate API.
- CLI entry points via `if __name__ == "__main__"` only in thin launchers; logic lives in importable modules.
<!-- /structure -->
<!-- tests -->
- pytest with fixtures (no unittest classes); Arrange-Act-Assert with blank-line separation.
- Parametrize over cases: `@pytest.mark.parametrize` for reject/accept tables.
- Async code through `pytest-asyncio`; network/containers via `testcontainers-python`, never live endpoints.
- Type-check the tests too: they run under `mypy --strict` like production code.
<!-- /tests -->
<!-- errors -->
- Raise specific exception types defined in the package (`PolicyNotFound`), never bare `Exception`.
- No silent `except:` / `except Exception: pass` — catch the narrowest type and log or wrap with context (`raise X from err`).
- `try/except/else/finally` over deep nesting; validate at the boundary, trust types inside.
<!-- /errors -->
<!-- quality -->
## Code quality

- `ruff check`, `ruff format` and `mypy --strict` are gates: green before every commit, no per-line suppressions without a why-comment.
- Test and build commands run through uv (`uv run pytest tests`, `uv build`); a bare `python3 -m pytest` is the documented fallback only when uv is unavailable.
- Logging via the stdlib `logging` (or structlog), parameterized: `log.info("policy %s approved", pid)` — never f-strings in log calls.
- No `print()` outside CLIs; pin dependencies with hashes in CI (`pip install --require-hashes`).
<!-- /quality -->
