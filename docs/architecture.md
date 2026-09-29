# Architecture

LedgerWeave follows a one-way pipeline:

`typed source records -> validation findings -> order balances -> balance findings -> report`

The model keeps order, payment, refund and adjustment identifiers separate. Lookup is only from an external record to a declared order. A missing target generates a finding rather than silently creating a balance.

## Money and time

Money is stored as an integer number of minor units. This prevents float rounding from changing equality and conservation checks. Days are input integers in the current MVP; calendar parsing and timezone conversion are deliberately out of scope.

## Balance equation

For each order:

`outstanding = (order amount + credits - debits) - captured payments + refunds`

A positive outstanding value is still owed. A negative value is over-collected. Refunds above captured payment are always blocking.

## Extension seam

New source adapters should convert their external format into `LedgerInput`; they must not bypass `validate` or mutate `ReconciliationResult`. New business rules should create a named `FindingCode`, include a stable record reference, and have both a positive and failure-path test.
