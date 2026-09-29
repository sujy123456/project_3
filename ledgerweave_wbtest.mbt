///|
test "captured total excludes voided records" {
  let input = {
    orders: [
      {
        id: "O",
        account_id: "a",
        currency: "CNY",
        amount_minor: 100,
        created_day: 1,
        status: Paid,
      },
    ],
    payments: [
      {
        id: "P1",
        order_id: "O",
        currency: "CNY",
        amount_minor: 100,
        received_day: 1,
        status: Captured,
      },
      {
        id: "P2",
        order_id: "O",
        currency: "CNY",
        amount_minor: 100,
        received_day: 1,
        status: Voided,
      },
    ],
    refunds: [],
    adjustments: [],
  }
  assert_eq(sum_captured(input, "O"), 100)
}

///|
test "duplicate ids are detected" {
  let input = {
    orders: [
      {
        id: "D",
        account_id: "a",
        currency: "CNY",
        amount_minor: 100,
        created_day: 1,
        status: Paid,
      },
      {
        id: "D",
        account_id: "b",
        currency: "CNY",
        amount_minor: 100,
        created_day: 1,
        status: Paid,
      },
    ],
    payments: [],
    refunds: [],
    adjustments: [],
  }
  let findings = validate(input, default_policy())
  assert_eq(findings.length(), 2)
  assert_eq(findings[0].code, DuplicateOrderId)
}

///|
test "credit and debit adjustments have opposite signs" {
  let input = {
    orders: [],
    payments: [],
    refunds: [],
    adjustments: [
      {
        id: "C",
        order_id: "O",
        currency: "CNY",
        amount_minor: 20,
        day: 1,
        direction: Credit,
        reason: "fee",
      },
      {
        id: "D",
        order_id: "O",
        currency: "CNY",
        amount_minor: 5,
        day: 1,
        direction: Debit,
        reason: "discount",
      },
    ],
  }
  assert_eq(sum_adjustments(input, "O"), 15)
}
