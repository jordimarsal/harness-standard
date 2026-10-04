<!-- harness:architecture:start -->
## Architecture: Hexagonal (Ports & Adapters)

- Source dependencies point **inward only** (adapter → port → domain); the domain
  imports no framework, ORM or transport type.
- Ports live in the domain and are named by role (`PolicyStore`), never by technology;
  adapters implement them and own the mapping.
- Every use case is driven through its inbound port — adapters never call each other
  and never reach into the domain except through use cases.
<!-- harness:architecture:end -->
