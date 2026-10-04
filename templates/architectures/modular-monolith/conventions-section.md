<!-- harness:architecture:start -->
## Architecture: Modular Monolith

- Modules expose a narrow published API; importing another module's internals is a
  build-breaking defect, not a shortcut.
- Each module owns its schema — no cross-module JOINs, no shared tables; cross-module
  reads go through the owning module's API or its in-process events.
- Module communication must stay extract-ready: a module migrates to a service by
  swapping its API transport, not by rewriting its internals.
<!-- harness:architecture:end -->
