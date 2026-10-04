<!-- harness:architecture:start -->
## Architecture: Layered (Traditional)

- Dependencies point **downward only** (Presentation → Business → Persistence); a
  review must reject upward or skip-layer calls.
- Business rules live **only** in the business layer — controllers, templates and SQL
  are rule-free zones.
- Each layer communicates through its published interface; reaching into another
  layer's internals is a defect.
<!-- harness:architecture:end -->
