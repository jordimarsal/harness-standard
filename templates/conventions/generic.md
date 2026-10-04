<!-- language: project language -->
<!-- style -->
- Define the formatting tool and its configuration here (formatter config file is the source of truth; CI enforces it).
- Set the complexity budget: max nesting, max function length, and what to do instead (extract helpers, early returns).
- State the immutability/paradigm defaults of the language as used in this project.
<!-- /style -->
<!-- naming -->
- State the casing rules per artifact (files, types, functions, constants) and the intent-first naming policy.
- One concept, one name across layers; booleans read as predicates; no abbreviations that need a legend.
<!-- /naming -->
<!-- structure -->
- Describe the folder layout and what each top-level directory owns.
- State where shared code lives and what may import what (dependency direction).
<!-- /structure -->
<!-- tests -->
- Name the test runner, the naming pattern for tests, and the behavior-stating requirement.
- List the boundaries to fake (network, clock, filesystem) and the tools used to fake them.
<!-- /tests -->
<!-- errors -->
- State how expected failures are modeled vs unexpected ones.
- Ban the anti-patterns of the language (swallowed exceptions, bare catches, silent defaults).
<!-- /errors -->
<!-- quality -->
## Code quality

- List the lint/format/type gates with their zero-warning policy.
- Name the logging library and its parameterized style; ban console/print debugging in shipped code.
<!-- /quality -->
