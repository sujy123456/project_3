///|

///|
test "clean ledger settles without findings" {
  let result = reconcile(clean_input(), default_policy(), 2)
  assert_true(result.valid)
  assert_eq(result.findings.length(), 0)
  assert_eq(result.balances[0].resolution, Settled)
  assert_eq(result.balances[0].outstanding_minor, 0)
}

///|
test "unknown payment is a blocking finding" {
  let result = reconcile(demo_input(), default_policy(), 40)
  let mut found = false
  for finding in result.findings {
    if finding.code == UnknownOrder {
      found = true
    }
  }
  assert_true(found)
  assert_false(result.valid)
}

///|
test "refund makes outstanding balance visible" {
  let result = reconcile(demo_input(), default_policy(), 4)
  assert_eq(result.balances[0].order_id, "ORD-100")
  assert_eq(result.balances[0].outstanding_minor, 2000)
  assert_eq(result.balances[0].resolution, AwaitingPayment)
}

///|
test "report labels retain actionable codes" {
  assert_eq(finding_code_label(UnknownOrder), "unknown_order")
  assert_eq(resolution_label(RefundRisk), "refund_risk")
}
