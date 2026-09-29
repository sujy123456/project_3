///|

///|
test "clean ledger settles without findings" {
  let result = @ledgerweave.reconcile(
    @ledgerweave.clean_input(),
    @ledgerweave.default_policy(),
    2,
  )
  assert_true(result.valid)
  assert_eq(result.findings.length(), 0)
  assert_eq(result.balances[0].resolution, Settled)
  assert_eq(result.balances[0].outstanding_minor, 0)
}

///|
test "unknown payment is a blocking finding" {
  let result = @ledgerweave.reconcile(
    @ledgerweave.demo_input(),
    @ledgerweave.default_policy(),
    40,
  )
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
  let result = @ledgerweave.reconcile(
    @ledgerweave.demo_input(),
    @ledgerweave.default_policy(),
    4,
  )
  assert_eq(result.balances[0].order_id, "ORD-100")
  assert_eq(result.balances[0].outstanding_minor, 2000)
  assert_eq(result.balances[0].resolution, AwaitingPayment)
}

///|
test "report labels retain actionable codes" {
  assert_eq(@ledgerweave.finding_code_label(UnknownOrder), "unknown_order")
  assert_eq(@ledgerweave.resolution_label(RefundRisk), "refund_risk")
}

///|
test "CSV adapters preserve a clean ledger" {
  let orders = "id,account_id,currency,amount_minor,created_day,status\nO-1,team,CNY,100,1,paid\n"
  let payments = "id,order_id,currency,amount_minor,received_day,status\nP-1,O-1,CNY,100,1,captured\n"
  let refunds = "id,order_id,currency,amount_minor,refunded_day,reason\n"
  let adjustments = "id,order_id,currency,amount_minor,day,direction,reason\n"
  let input = @ledgerweave.parse_ledger_csv(
    orders, payments, refunds, adjustments,
  )
  let result = @ledgerweave.reconcile(input, @ledgerweave.default_policy(), 2)
  assert_true(result.valid)
  assert_eq(result.balances.length(), 1)
}

///|
test "CSV parser accepts quoted commas and escaped quotes" {
  let rows = @ledgerweave.parse_csv(
    "id,reason\nA-1,\"customer said \"\"hello\"\", then left\"\n",
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[1][1], "customer said \"hello\", then left")
}

///|
test "invalid day value defaults safely to zero" {
  assert_eq(@ledgerweave.parse_day("oops"), 0)
  assert_eq(@ledgerweave.parse_day("42"), 42)
}
