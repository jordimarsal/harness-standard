<!-- harness:architecture:start -->
## Architecture: CQRS

- Commands mutate and return an acknowledgment; queries return data and mutate
  nothing — a handler doing both is a defect.
- All invariants live on the write side; read models are denormalized projections,
  rebuildable from the source of truth, rule-free.
- Read and write models share no types; read-side lag is documented, never hidden.
<!-- harness:architecture:end -->
