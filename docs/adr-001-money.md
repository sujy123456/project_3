# ADR 001: integer minor-unit money

## Status
Accepted.

## Decision
LedgerWeave stores money as `Int` minor units instead of floating-point numbers.

## Consequences
Equality, tolerance checks and balance conservation are deterministic. Callers must normalize their decimal exports before constructing typed records.
