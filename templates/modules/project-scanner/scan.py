#!/usr/bin/env python3
"""Deterministic project scanner (harness project-scanner module).

v1 scope: Python AST analysis plus a generic file-count fallback.
The project is parsed exactly once; all queries are answered from indexes.

Usage (from the project root):
  python3 harness/tools/scan.py --summary          Project overview (default)
  python3 harness/tools/scan.py --impact FILE      Impact analysis for one file
  python3 harness/tools/scan.py --duplicates       Symbols defined in 2+ modules
  python3 harness/tools/scan.py --style [N]        Style sample of N files (default 3)
  python3 harness/tools/scan.py --root DIR         Scan a different root

Exit codes: 0 ok, 2 usage error.
"""

from __future__ import annotations

import ast
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

EXCLUDED_DIRS = {
    ".git", ".hg", ".svn", ".venv", "venv", "env", "__pycache__",
    "node_modules", ".tox", ".mypy_cache", ".pytest_cache",
    "build", "dist", ".harness", "harness",
}
REGION_RE = re.compile(r"#\s*region\s+(.+)")


@dataclass
class SourceFile:
    path: Path  # relative to the project root
    module: str  # dotted module name, e.g. "core.models"
    imports: list[str] = field(default_factory=list)
    classes: list[str] = field(default_factory=list)
    functions: list[str] = field(default_factory=list)
    docstring: str | None = None
    entry_point: bool = False
    regions: list[str] = field(default_factory=list)
    dependencies: set[str] = field(default_factory=set)  # resolved relative paths


class Scanner:
    """Parses every Python file once, then serves queries from dict indexes."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.files: list[SourceFile] = []
        self._by_module: dict[str, SourceFile] = {}
        self._dependents: dict[str, set[str]] = {}

    def scan(self) -> None:
        for p in self.root.rglob("*.py"):
            if set(p.parts) & EXCLUDED_DIRS:
                continue
            sf = self._parse(p)
            if sf is not None:
                self.files.append(sf)
        self._build_indexes()

    def _parse(self, path: Path) -> SourceFile | None:
        rel = path.relative_to(self.root)
        try:
            text = path.read_text(encoding="utf-8")
            tree = ast.parse(text)
        # UnicodeDecodeError derives from ValueError, so listing it would be redundant.
        except (SyntaxError, OSError, ValueError):
            return None  # unreadable files are skipped, never fatal
        sf = SourceFile(path=rel, module=self._module_name(rel))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                sf.imports.extend(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                sf.imports.append(node.module)
            elif isinstance(node, ast.ClassDef):
                sf.classes.append(node.name)
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                sf.functions.append(node.name)
        sf.docstring = ast.get_docstring(tree)
        sf.entry_point = "__main__" in text
        sf.regions = [m.group(1).strip() for m in REGION_RE.finditer(text)]
        return sf

    @staticmethod
    def _module_name(rel: Path) -> str:
        parts = list(rel.with_suffix("").parts)
        if parts and parts[-1] == "__init__":
            parts = parts[:-1]
        return ".".join(parts)

    def _build_indexes(self) -> None:
        self._index_modules()
        self._index_dependencies()

    def _index_modules(self) -> None:
        # Index every dotted suffix of each module name; the longest key wins.
        # "src/core/models.py" registers "src.core.models", "core.models", "models".
        for sf in self.files:
            parts = sf.module.split(".") if sf.module else []
            for i in range(len(parts)):
                key = ".".join(parts[i:])
                current = self._by_module.get(key)
                if current is None or len(parts) > len(current.module.split(".")):
                    self._by_module[key] = sf

    def _index_dependencies(self) -> None:
        # Reverse-dependency index, built once — never per query.
        for sf in self.files:
            for imp in sf.imports:
                target = self._resolve(imp)
                if target is not None and target.path != sf.path:
                    sf.dependencies.add(str(target.path))
                    self._dependents.setdefault(str(target.path), set()).add(str(sf.path))

    def _resolve(self, module: str) -> SourceFile | None:
        # Longest registered suffix match: "core.models" beats "models".
        parts = module.split(".")
        for i in range(len(parts)):
            key = ".".join(parts[i:])
            if key in self._by_module:
                return self._by_module[key]
        return None

    def affected_by(self, rel_path: str) -> set[str]:
        return set(self._dependents.get(rel_path, set()))

    def find_duplicates(self) -> dict[str, list[str]]:
        seen: dict[str, list[str]] = {}
        for sf in self.files:
            for name in sf.classes + sf.functions:
                seen.setdefault(name, []).append(str(sf.path))
        dupes: dict[str, list[str]] = {}
        for name, paths in seen.items():
            unique = sorted(set(paths))
            if len(unique) > 1:
                dupes[name] = unique
        return dupes

    def risk(self, sf: SourceFile) -> str:
        score = 0
        if self._dependents.get(str(sf.path)):
            score += 2
        if sf.classes:
            score += 1
        if sf.entry_point:
            score += 1
        if not sf.docstring:
            score += 1
        if score >= 4:
            return "HIGH"
        if score >= 2:
            return "MEDIUM"
        return "LOW"


def cmd_summary(sc: Scanner) -> str:
    files = sc.files
    if not files:
        return generic_summary(sc.root)
    test_files = [f for f in files if "test" in f.path.name or "test" in f.path.parent.name]
    entry_points = [f for f in files if f.entry_point]
    missing_docs = [f for f in files if f.classes and not f.docstring]
    edges = sum(len(f.dependencies) for f in files)
    high = [f for f in files if sc.risk(f) == "HIGH"]
    packages = sorted({str(f.path.parent) for f in files})
    dupes = sc.find_duplicates()
    return "\n".join([
        "## Project Reading Summary",
        f"- Total Python files: {len(files)}",
        f"- Test files: {len(test_files)}",
        f"- Packages: {len(packages)}",
        f"- Import graph edges: {edges}",
        "- Files: " + ", ".join(str(f.path) for f in files),
        "- Entry points: " + (", ".join(str(f.path) for f in entry_points) or "none"),
        f"- Files with classes and no docstring: {len(missing_docs)}",
        "- HIGH-risk files: " + (", ".join(str(f.path) for f in high) or "none"),
        "- Duplicated symbols: " + (", ".join(sorted(dupes)) or "none"),
    ])


def generic_summary(root: Path) -> str:
    counts: dict[str, int] = {}
    for p in root.rglob("*"):
        if p.is_file() and not (set(p.parts) & EXCLUDED_DIRS):
            key = p.suffix or "(no extension)"
            counts[key] = counts.get(key, 0) + 1
    lines = ["## Project Reading Summary (generic fallback - no Python files)"]
    for ext, n in sorted(counts.items(), key=lambda kv: -kv[1])[:10]:
        lines.append(f"- {ext}: {n} files")
    if len(lines) == 1:
        lines.append("- (empty project)")
    return "\n".join(lines)


def _find_file(sc: Scanner, target: str) -> SourceFile | None:
    path = Path(target)
    sf = next((f for f in sc.files if f.path == path), None)
    if sf is None and path.is_absolute():
        try:
            rel = path.resolve().relative_to(sc.root.resolve())
        except ValueError:
            rel = None
        if rel is not None:
            sf = next((f for f in sc.files if f.path == rel), None)
    return sf


def cmd_impact(sc: Scanner, target: str) -> str:
    sf = _find_file(sc, target)
    if sf is None:
        return f"error: file not found in project: {target}"
    dependents = sorted(sc.affected_by(str(sf.path)))
    tests = [d for d in dependents if "test" in d]
    return "\n".join([
        f"## Impact analysis - {sf.path}",
        "- Dependencies: " + (", ".join(sorted(sf.dependencies)) or "none"),
        "- Dependents: " + (", ".join(dependents) or "none"),
        "- Tests affected: " + (", ".join(tests) or "none"),
        "- Impact level: " + ("HIGH" if dependents else "MEDIUM"),
        f"- Change risk: {sc.risk(sf)}",
    ])


def cmd_duplicates(sc: Scanner) -> str:
    dupes = sc.find_duplicates()
    if not dupes:
        return "## Duplicates\n- none"
    lines = ["## Duplicates"]
    for name in sorted(dupes):
        lines.append(f"- {name}: {', '.join(dupes[name])}")
    return "\n".join(lines)


def cmd_style(sc: Scanner, n: int) -> str:
    sample = [f for f in sc.files if "test" not in f.path.name][:n]
    lines = ["## Style sample"]
    for sf in sample:
        lines.append(
            f"- {sf.path}: classes={sf.classes or '-'}"
            f" regions={sf.regions or '-'}"
            f" first_imports={sf.imports[:3] or '-'}"
        )
    if not sample:
        lines.append("- (no Python files found)")
    return "\n".join(lines)


def json_summary(sc: Scanner) -> dict:
    files = sc.files
    test_files = [f for f in files if "test" in f.path.name or "test" in f.path.parent.name]
    entry_points = [f for f in files if f.entry_point]
    missing_docs = [f for f in files if f.classes and not f.docstring]
    high = [f for f in files if sc.risk(f) == "HIGH"]
    packages = sorted({str(f.path.parent) for f in files})
    return {
        "tool": "scan",
        "protocol": 1,
        "command": "summary",
        "stack": "python" if files else "generic",
        "files": sorted(str(f.path) for f in files),
        "total_files": len(files),
        "test_files": len(test_files),
        "packages": len(packages),
        "edges": sum(len(f.dependencies) for f in files),
        "entry_points": [str(f.path) for f in entry_points],
        "missing_docstrings": len(missing_docs),
        "high_risk": [str(f.path) for f in high],
        "duplicates": sc.find_duplicates(),
    }


def json_impact(sc: Scanner, target: str) -> dict:
    sf = _find_file(sc, target)
    if sf is None:
        return {"tool": "scan", "protocol": 1, "command": "impact", "error": f"file not found in project: {target}"}
    dependents = sorted(sc.affected_by(str(sf.path)))
    tests = [d for d in dependents if "test" in d]
    return {
        "tool": "scan",
        "protocol": 1,
        "command": "impact",
        "file": str(sf.path),
        "dependencies": sorted(sf.dependencies),
        "dependents": dependents,
        "tests_affected": tests,
        "impact_level": "HIGH" if dependents else "MEDIUM",
        "change_risk": sc.risk(sf),
    }


class UsageError(Exception):
    """Raised for malformed CLI usage; main prints it and exits 2."""


COMMANDS = ("--summary", "--duplicates", "--impact", "--style")
KNOWN_FLAGS = ("--json", *COMMANDS, "--root")


def _take_value(flag: str, remaining: list[str]) -> str | None:
    """Remove `flag` and its (required) value from remaining; None if absent."""
    if flag not in remaining:
        return None
    i = remaining.index(flag)
    if i + 1 >= len(remaining):
        raise UsageError(f"{flag} requires a value")
    value = remaining[i + 1]
    del remaining[i : i + 2]
    return value


def _take_style(remaining: list[str]) -> int:
    """Remove `--style` and its optional bare-number count; default 3."""
    if "--style" not in remaining:
        return 3
    i = remaining.index("--style")
    style_n = 3
    if i + 1 < len(remaining) and remaining[i + 1].isdigit():
        style_n = int(remaining[i + 1])
        del remaining[i + 1]
    del remaining[i]
    return style_n


def parse_args(argv: list[str]) -> "tuple[str, str | None, int, bool, Path] | int":
    """Parse CLI flags; return (command, target, style_n, as_json, root) or exit code 2."""
    try:
        as_json = "--json" in argv
        command = next((c for c in COMMANDS if c in argv), "--summary")
        remaining = list(argv)
        target = _take_value("--impact", remaining)
        root = Path(_take_value("--root", remaining) or Path.cwd())
        style_n = _take_style(remaining)
        unknown = [a for a in remaining if a.startswith("-") and a not in KNOWN_FLAGS]
        if unknown:
            raise UsageError(f"unknown argument: {unknown[0]}")
    except UsageError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return command, target, style_n, as_json, root


def emit(sc: Scanner, command: str, target: str | None, style_n: int, as_json: bool) -> None:
    """Print the selected command's report in the requested format."""
    if as_json:
        if command == "--summary":
            print(json.dumps(json_summary(sc)))
        elif command == "--impact":
            print(json.dumps(json_impact(sc, target or "")))
        elif command == "--duplicates":
            print(json.dumps({"tool": "scan", "protocol": 1, "command": "duplicates", "duplicates": sc.find_duplicates()}))
        elif command == "--style":
            print(json.dumps({"tool": "scan", "protocol": 1, "command": "style", "sample": [
                {"path": str(sf.path), "classes": sf.classes, "regions": sf.regions, "first_imports": sf.imports[:3]}
                for sf in [f for f in sc.files if "test" not in f.path.name][:style_n]
            ]}))
        return
    if command == "--summary":
        print(cmd_summary(sc))
    elif command == "--impact":
        print(cmd_impact(sc, target or ""))
    elif command == "--duplicates":
        print(cmd_duplicates(sc))
    elif command == "--style":
        print(cmd_style(sc, style_n))


def main(argv: list[str]) -> int:
    parsed = parse_args(argv)
    if isinstance(parsed, int):
        return parsed
    command, target, style_n, as_json, root = parsed
    sc = Scanner(root)
    sc.scan()
    emit(sc, command, target, style_n, as_json)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
