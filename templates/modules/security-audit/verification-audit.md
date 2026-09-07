## Security Audit Checklist (security-audit module)

> Appended by the harness `security-audit` module. The reviewer applies this
> checklist manually at `audit_level: basic`, and runs
> `bash harness/tools/audit-security.sh` at `standard` and above. Findings are
> recorded in the feature's progress entry with severity (HIGH/MEDIUM/LOW),
> description, and resolution or explicit waiver.

### A01 Broken Access Control
- [ ] Sensitive endpoints and operations require authentication.
- [ ] Role/permission checks enforced server-side, not only in the UI.

### A02 Cryptographic Failures
- [ ] No hardcoded secrets; credentials come from environment or a secrets manager.
- [ ] Cryptographic randomness from the stack's secure source (`secrets`, `crypto`).
- [ ] Sensitive data encrypted at rest and in transit where required.

### A03 Injection
- [ ] SQL via parameterized queries only — never string concatenation.
- [ ] No `shell=True` or unsanitized shell interpolation; file paths validated against traversal.
- [ ] HTML/JSON output escaped (XSS) when data reaches a UI.

### A04 Insecure Design
- [ ] External input validated (type, range, format, length) at the boundary.
- [ ] Rate limiting and retry-with-backoff considered for public endpoints.

### A05 Security Misconfiguration
- [ ] No debug mode, verbose stack traces, or default credentials in production config.
- [ ] Error messages generic externally; internal detail logged securely, without PII.

### API security headers (when serving HTTP)

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
Permissions-Policy: <deny unused browser capabilities>
Referrer-Policy: no-referrer
Cache-Control: no-store          # only for sensitive responses
```

(Deprecated `X-XSS-Protection` is intentionally not listed.)

### Automated scanning (audit_level standard and above)

Run `bash harness/tools/audit-security.sh` from the project root. The script uses
the stack's tools when installed and degrades to this checklist otherwise — it
must never be a blocker by itself; HIGH findings it reports reject the approval.

### Report format (in the review file)

```markdown
## Security Audit
- Method: manual checklist | audit-security.sh
- Findings:
  - [HIGH/MEDIUM/LOW] <description> — <resolution or waiver>
- Result: PASS | REJECTED (HIGH findings unresolved)
```
