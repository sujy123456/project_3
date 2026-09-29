# Quality and maintenance policy

Every change must pass formatting, `moon check`, `moon test`, and a native build. CI runs those commands on pull requests and pushes.

Core invariants are tested with both clean and intentionally inconsistent fixtures: captured totals ignore voids; duplicate identifiers are findings; adjustment signs are deterministic; an unknown reference blocks validity; a refund changes the balance equation.

Known MVP boundaries are CSV/JSONL adapters, persisted policy files, decimal input parsing, and machine-readable JSON reports. The domain model is usable today as a MoonBit library and the executable demonstrates a full in-memory reconciliation flow.
