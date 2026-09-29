///|
/// A deliberately mixed fixture used by the executable demo and integration tests.
pub fn demo_input() -> LedgerInput {
  {
    orders: [
      {
        id: "ORD-100",
        account_id: "acme",
        currency: "CNY",
        amount_minor: 12000,
        created_day: 1,
        status: Paid,
      },
      {
        id: "ORD-200",
        account_id: "acme",
        currency: "CNY",
        amount_minor: 8000,
        created_day: 1,
        status: Paid,
      },
      {
        id: "ORD-300",
        account_id: "beta",
        currency: "USD",
        amount_minor: 5000,
        created_day: 1,
        status: Cancelled,
      },
    ],
    payments: [
      {
        id: "PAY-1",
        order_id: "ORD-100",
        currency: "CNY",
        amount_minor: 12000,
        received_day: 2,
        status: Captured,
      },
      {
        id: "PAY-2",
        order_id: "ORD-200",
        currency: "CNY",
        amount_minor: 6000,
        received_day: 3,
        status: Captured,
      },
      {
        id: "PAY-3",
        order_id: "ORD-300",
        currency: "USD",
        amount_minor: 5000,
        received_day: 3,
        status: Captured,
      },
      {
        id: "PAY-4",
        order_id: "MISSING",
        currency: "CNY",
        amount_minor: 100,
        received_day: 3,
        status: Captured,
      },
    ],
    refunds: [
      {
        id: "REF-1",
        order_id: "ORD-100",
        currency: "CNY",
        amount_minor: 2000,
        refunded_day: 4,
        reason: "partial return",
      },
    ],
    adjustments: [
      {
        id: "ADJ-1",
        order_id: "ORD-200",
        currency: "CNY",
        amount_minor: 500,
        day: 2,
        direction: Credit,
        reason: "shipping",
      },
    ],
  }
}

///|
pub fn clean_input() -> LedgerInput {
  {
    orders: [
      {
        id: "ORD-CLEAN",
        account_id: "demo",
        currency: "CNY",
        amount_minor: 1000,
        created_day: 1,
        status: Paid,
      },
    ],
    payments: [
      {
        id: "PAY-CLEAN",
        order_id: "ORD-CLEAN",
        currency: "CNY",
        amount_minor: 1000,
        received_day: 2,
        status: Captured,
      },
    ],
    refunds: [],
    adjustments: [],
  }
}
