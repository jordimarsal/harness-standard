<!-- harness:architecture:start -->
## Architecture: Event-Driven

- Events are past-tense, immutable facts carrying what consumers need; consumers
  never call producers back to reconstruct context.
- Every handler is idempotent (at-least-once delivery) with an explicit dedup key;
  event payloads are versioned — breaking changes ship as new versions.
- State change and event publication share one transaction (transactional outbox);
  events carry correlation and causation ids end to end.
<!-- harness:architecture:end -->
