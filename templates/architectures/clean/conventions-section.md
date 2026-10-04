<!-- harness:architecture:start -->
## Architecture: Clean

- The dependency rule is absolute: entities ← use cases ← adapters ← frameworks;
  no inner circle imports from an outer one.
- Data crosses boundaries as simple structures owned by the inner layer; frameworks
  and ORM types never appear in entities or use cases.
- Delivery formatting happens in presenters/controllers — use cases never return
  transport-ready payloads.
<!-- harness:architecture:end -->
