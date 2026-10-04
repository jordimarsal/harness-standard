<!-- harness:architecture:start -->
## Architecture: Microservices

- Each service owns its datastore exclusively; cross-service access happens through
  versioned APIs or events — shared databases and shared domain libraries are banned.
- Service boundaries follow business capabilities; a change requiring lock-step
  deployment of two services is a boundary defect.
- Resilience is contractual: timeouts, retry-with-backoff, idempotent handlers and
  correlation-id propagation in every call path; long-running flows are sagas with
  compensation, never distributed transactions.
<!-- harness:architecture:end -->
