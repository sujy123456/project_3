# LedgerWeave

LedgerWeave is a MoonBit reconciliation engine for multi-source business ledgers. It compares orders, captured payments, refunds, and adjustments under an explicit policy, then produces per-order balances and actionable exception findings.

It is designed for offline, deterministic review before a team acts on a monthly or daily settlement file. Amounts use integer minor units: `12000` represents CNY 120.00.

## What it checks

- duplicate identifiers within each source;
- positive amounts and allowed currencies;
- unknown order references and cross-record currency mismatches;
- payment timing windows and payments against cancelled orders;
- refund total not exceeding captured payment;
- underpayment, over-collection, and overdue open balances.

## Scope and boundaries

LedgerWeave does not connect to bank accounts, move money, calculate tax, or claim accounting compliance. It evaluates only supplied records under a versioned, explicit policy. A passing result means no blocking inconsistency was found in that input; it is not an audit opinion.

## Requirements

- MoonBit `>= 0.10.14` (developed with `moon 0.1.20260920`)

## Run the included example

```bash
moon check
moon test
moon run cmd/main
```

The demo intentionally contains an unknown payment and a payment for a cancelled order. Its report therefore ends in `REVIEW REQUIRED` and explains each exception.

## Library usage

```moonbit nocheck
let policy = @ledgerweave.default_policy()
let input : @ledgerweave.LedgerInput = {
  orders: [{ id: "ORD-1", account_id: "team", currency: "CNY", amount_minor: 1000, created_day: 1, status: Paid }],
  payments: [{ id: "PAY-1", order_id: "ORD-1", currency: "CNY", amount_minor: 1000, received_day: 1, status: Captured }],
  refunds: [],
  adjustments: [],
}
let result = @ledgerweave.reconcile(input, policy, 1)
assert_true(result.valid)
```

## Architecture

`LedgerInput` is immutable input. `validate` performs source-level checks. `reconcile` computes captured, refunded and adjusted balances for every known order, then derives balance findings. `report` converts only the structured result into terminal-safe text. No report function changes ledger state.

See [architecture](docs/architecture.md), [quality policy](docs/quality.md), and [third-party notices](THIRD_PARTY_NOTICES.md).

## Development

```bash
moon fmt
moon check
moon test
moon build --target native
moon publish --dry-run
```

## License

Apache-2.0. See [LICENSE](LICENSE). The first release has no third-party runtime dependencies; details are recorded in `THIRD_PARTY_NOTICES.md`.

## CSV command-line workflow

The native CLI accepts four CSV files plus the current business day:

```bash
moon run --target native cmd/main -- \
  examples/csv/orders.csv examples/csv/payments.csv \
  examples/csv/refunds.csv examples/csv/adjustments.csv 40
```

The headers are fixed and intentional: `orders` requires `id,account_id,currency,amount_minor,created_day,status`; payments use `id,order_id,currency,amount_minor,received_day,status`; refunds use `id,order_id,currency,amount_minor,refunded_day,reason`; and adjustments use `id,order_id,currency,amount_minor,day,direction,reason`.

CSV values may be quoted and use doubled quotes for literal quotes. Unreadable files terminate the native CLI through its explicit filesystem error boundary. Missing columns or malformed numeric values are converted to empty/zero fields and are subsequently surfaced by LedgerWeave validation instead of being silently accepted.

## Extended audit capabilities

LedgerWeave also provides library APIs for operational reconciliation workflows:

- `analytics.mbt`: severity, exception-code, currency, account and aging metrics.
- `matching.mbt`: deterministic captured-payment allocation plans, unmatched payment detection and over-allocation tracking.
- `quality.mbt`: pre-reconciliation source profiling with row-level quality issues.
- `review.mbt`: owned exception cases, assignment rules, state transitions and overdue queues.
- `export.mbt`: RFC-style escaped CSV and Markdown audit exports.

These APIs are deterministic and do not mutate the original input records. The regression suite covers exact, excess, unmatched, voided and currency-conflicting payments; review lifecycle rules; source-quality defects; and export escaping.
