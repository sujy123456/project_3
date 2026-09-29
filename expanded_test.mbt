///| Extended regression tests for analytics, allocation, review workflow, and input quality.

///|
fn base_order(
  id : String,
  account : String,
  amount : Int,
  day : Int,
) -> OrderRecord {
  {
    id,
    account_id: account,
    currency: "CNY",
    amount_minor: amount,
    created_day: day,
    status: Paid,
  }
}

///|
fn base_payment(
  id : String,
  order_id : String,
  amount : Int,
  day : Int,
) -> PaymentRecord {
  {
    id,
    order_id,
    currency: "CNY",
    amount_minor: amount,
    received_day: day,
    status: Captured,
  }
}

///|
fn allocation_input() -> LedgerInput {
  {
    orders: [
      base_order("A-1", "alpha", 100, 1),
      base_order("A-2", "beta", 200, 2),
    ],
    payments: [
      base_payment("P-1", "A-1", 100, 1),
      base_payment("P-2", "A-2", 250, 3),
      base_payment("P-3", "MISSING", 30, 3),
    ],
    refunds: [],
    adjustments: [],
  }
}

///|
test "analytics counts errors and warnings independently" {
  let findings : Array[Finding] = [
    make_finding(UnknownOrder, Error, Payment, "P-1", "O-1", "unknown"),
    make_finding(Underpaid, Warning, Order, "O-1", "O-1", "under"),
    make_finding(PaymentVoided, Info, Payment, "P-2", "O-2", "void"),
  ]
  let metrics = finding_metrics(findings)
  assert_eq(metrics.total, 3)
  assert_eq(metrics.error, 1)
  assert_eq(metrics.warning, 1)
  assert_eq(metrics.info, 1)
  assert_eq(metrics.blocking, 1)
}

///|
test "finding query applies severity threshold" {
  let findings : Array[Finding] = [
    make_finding(UnknownOrder, Error, Payment, "P-1", "O-1", "unknown"),
    make_finding(Underpaid, Warning, Order, "O-1", "O-1", "under"),
    make_finding(PaymentVoided, Info, Payment, "P-2", "O-2", "void"),
  ]
  let selected = filter_findings(findings, {
    minimum_severity: Warning,
    code: None,
    order_id: None,
    record_kind: None,
  })
  assert_eq(selected.length(), 2)
  assert_eq(selected[0].severity, Error)
  assert_eq(selected[1].severity, Warning)
}

///|
test "finding query filters by order and code" {
  let findings : Array[Finding] = [
    make_finding(UnknownOrder, Error, Payment, "P-1", "O-1", "unknown"),
    make_finding(UnknownOrder, Error, Payment, "P-2", "O-2", "unknown"),
    make_finding(Underpaid, Warning, Order, "O-1", "O-1", "under"),
  ]
  let selected = filter_findings(findings, {
    minimum_severity: Info,
    code: Some(UnknownOrder),
    order_id: Some("O-1"),
    record_kind: Some(Payment),
  })
  assert_eq(selected.length(), 1)
  assert_eq(selected[0].record_id, "P-1")
}

///|
test "balance helpers select outstanding extremes" {
  let balances : Array[OrderBalance] = [
    {
      order_id: "A",
      expected_minor: 100,
      captured_minor: 100,
      refunded_minor: 0,
      adjustments_minor: 0,
      outstanding_minor: 0,
      resolution: Settled,
    },
    {
      order_id: "B",
      expected_minor: 200,
      captured_minor: 100,
      refunded_minor: 0,
      adjustments_minor: 0,
      outstanding_minor: 100,
      resolution: AwaitingPayment,
    },
    {
      order_id: "C",
      expected_minor: 100,
      captured_minor: 150,
      refunded_minor: 0,
      adjustments_minor: 0,
      outstanding_minor: -50,
      resolution: OverCollected,
    },
  ]
  match max_outstanding_balance(balances) {
    Some(balance) => assert_eq(balance.order_id, "B")
    None => abort("expected maximum")
  }
  match min_outstanding_balance(balances) {
    Some(balance) => assert_eq(balance.order_id, "C")
    None => abort("expected minimum")
  }
}

///|
test "balance sorting orders largest outstanding first" {
  let balances : Array[OrderBalance] = [
    {
      order_id: "A",
      expected_minor: 100,
      captured_minor: 100,
      refunded_minor: 0,
      adjustments_minor: 0,
      outstanding_minor: 0,
      resolution: Settled,
    },
    {
      order_id: "B",
      expected_minor: 200,
      captured_minor: 100,
      refunded_minor: 0,
      adjustments_minor: 0,
      outstanding_minor: 100,
      resolution: AwaitingPayment,
    },
    {
      order_id: "C",
      expected_minor: 100,
      captured_minor: 150,
      refunded_minor: 0,
      adjustments_minor: 0,
      outstanding_minor: -50,
      resolution: OverCollected,
    },
  ]
  let sorted = sort_balances_by_outstanding(balances)
  assert_eq(sorted[0].order_id, "B")
  assert_eq(sorted[1].order_id, "A")
  assert_eq(sorted[2].order_id, "C")
}

///|
test "age bucket boundary labels are stable" {
  assert_eq(age_bucket_label(-1), "invalid")
  assert_eq(age_bucket_label(0), "0-7")
  assert_eq(age_bucket_label(7), "0-7")
  assert_eq(age_bucket_label(8), "8-30")
  assert_eq(age_bucket_label(30), "8-30")
  assert_eq(age_bucket_label(31), "31-60")
  assert_eq(age_bucket_label(60), "31-60")
  assert_eq(age_bucket_label(61), "61+")
}

///|
test "quality score rewards clean result" {
  let result = reconcile(clean_input(), default_policy(), 3)
  assert_eq(quality_score(result), 100)
  assert_true(is_healthy(result))
}

///|
test "quality score is reduced by findings" {
  let result = reconcile(demo_input(), default_policy(), 40)
  assert_true(quality_score(result) < 100)
  assert_false(is_healthy(result))
}

///|
test "currency and account totals aggregate balances" {
  let input = allocation_input()
  let result = reconcile(input, default_policy(), 5)
  let currencies = totals_by_currency(input, result)
  let accounts = totals_by_account(input, result)
  assert_eq(currencies.length(), 1)
  assert_eq(currencies[0].currency, "CNY")
  assert_eq(currencies[0].expected_minor, 300)
  assert_eq(accounts.length(), 2)
  assert_eq(accounts[0].account_id, "alpha")
  assert_eq(accounts[1].account_id, "beta")
}

///|
test "allocation applies exact payment and tracks excess" {
  let input = allocation_input()
  let result = reconcile(input, default_policy(), 5)
  let plan = allocate_payments(input, result)
  assert_eq(plan.allocated_minor, 300)
  assert_eq(plan.unallocated_minor, 80)
  assert_false(plan.valid)
  assert_eq(allocated_for_order(plan.allocations, "A-1"), 100)
  assert_eq(allocated_for_order(plan.allocations, "A-2"), 200)
  assert_eq(excess_for_payment(plan.allocations, "P-2"), 50)
}

///|
test "allocation preserves unmatched payment amount" {
  let input = allocation_input()
  let result = reconcile(input, default_policy(), 5)
  let plan = allocate_payments(input, result)
  let unmatched = unmatched_allocations(plan)
  assert_eq(unmatched.length(), 1)
  assert_eq(unmatched[0].payment_id, "P-3")
  assert_eq(unmatched[0].allocated_minor, 30)
  assert_eq(unmatched[0].state, UnmatchedPayment)
}

///|
test "allocation ignores voided payments" {
  let input : LedgerInput = {
    orders: [base_order("A", "team", 100, 1)],
    payments: [
      {
        id: "V",
        order_id: "A",
        currency: "CNY",
        amount_minor: 100,
        received_day: 2,
        status: Voided,
      },
    ],
    refunds: [],
    adjustments: [],
  }
  let result = reconcile(input, default_policy(), 3)
  let plan = allocate_payments(input, result)
  assert_eq(plan.allocations.length(), 1)
  assert_eq(plan.allocations[0].state, IgnoredPayment)
  assert_eq(plan.allocated_minor, 0)
  assert_true(allocation_plan_is_consistent(plan))
}

///|
test "allocation rejects currency conflict" {
  let input : LedgerInput = {
    orders: [base_order("A", "team", 100, 1)],
    payments: [
      {
        id: "P",
        order_id: "A",
        currency: "USD",
        amount_minor: 100,
        received_day: 2,
        status: Captured,
      },
    ],
    refunds: [],
    adjustments: [],
  }
  let result = reconcile(input, default_policy(), 3)
  let plan = allocate_payments(input, result)
  assert_eq(plan.allocations.length(), 1)
  assert_eq(plan.allocations[0].state, CurrencyConflict)
  assert_false(plan.valid)
  assert_true(allocation_plan_is_consistent(plan))
}

///|
test "candidate scores prefer exact relationship" {
  let input = allocation_input()
  let payment = base_payment("P", "A-1", 100, 2)
  match best_candidate(input, payment) {
    Some(candidate) => {
      assert_eq(candidate.order_id, "A-1")
      assert_eq(candidate.score, 100)
    }
    None => abort("expected candidate")
  }
}

///|
test "review queue materializes warning and error findings" {
  let findings : Array[Finding] = [
    make_finding(UnknownOrder, Error, Payment, "P", "O", "unknown"),
    make_finding(Underpaid, Warning, Order, "O", "O", "under"),
    make_finding(PaymentVoided, Info, Payment, "V", "O", "void"),
  ]
  let result : ReconciliationResult = { balances: [], findings, valid: false, }
  let queue = queue_from_result(result, 10)
  assert_eq(queue.cases.length(), 2)
  assert_eq(queue.cases[0].case_id, "CASE-1")
  assert_eq(queue.cases[0].priority, 1)
  assert_eq(queue.cases[1].priority, 2)
  assert_true(review_queue_is_consistent(queue))
}

///|
test "review assignment and transition are monotonic in time" {
  let finding = make_finding(Underpaid, Warning, Order, "O", "O", "under")
  let queue = enqueue_finding(empty_review_queue(), finding, 10)
  let assigned = assign_case(queue, "CASE-1", "finance", 11)
  let stale = assign_case(assigned, "CASE-1", "ops", 10)
  let active = transition_case(stale, "CASE-1", Investigating, 12)
  match find_review_case(active.cases, "CASE-1") {
    Some(case) => {
      assert_eq(case.owner, "finance")
      assert_eq(case.state, Investigating)
      assert_eq(case.updated_day, 12)
    }
    None => abort("expected case")
  }
}

///|
test "review decisions require terminal state and note" {
  let finding = make_finding(Underpaid, Warning, Order, "O", "O", "under")
  let queue = enqueue_finding(empty_review_queue(), finding, 10)
  let rejected = decide_case(queue, "CASE-1", DataCorrection, "fixed", 11)
  let resolved = transition_case(queue, "CASE-1", Resolved, 11)
  let missing_note = decide_case(resolved, "CASE-1", DataCorrection, "", 12)
  let decided = decide_case(
    resolved,
    "CASE-1",
    DataCorrection,
    "source corrected",
    12,
  )
  match find_review_case(rejected.cases, "CASE-1") {
    Some(case) => assert_eq(case.decision, NoDecision)
    None => abort("expected case")
  }
  match find_review_case(missing_note.cases, "CASE-1") {
    Some(case) => assert_eq(case.decision, NoDecision)
    None => abort("expected case")
  }
  match find_review_case(decided.cases, "CASE-1") {
    Some(case) => {
      assert_eq(case.decision, DataCorrection)
      assert_eq(case.resolution_note, "source corrected")
    }
    None => abort("expected case")
  }
}

///|
test "reopening clears terminal decision" {
  let finding = make_finding(UnknownOrder, Error, Payment, "P", "O", "unknown")
  let queue = enqueue_finding(empty_review_queue(), finding, 1)
  let resolved = transition_case(queue, "CASE-1", Resolved, 2)
  let decided = decide_case(resolved, "CASE-1", ConfirmedIssue, "confirmed", 3)
  let reopened = reopen_case(decided, "CASE-1", 4)
  match find_review_case(reopened.cases, "CASE-1") {
    Some(case) => {
      assert_eq(case.state, Investigating)
      assert_eq(case.decision, NoDecision)
      assert_eq(case.resolution_note, "")
    }
    None => abort("expected case")
  }
}

///|
test "review summary reports owners and overdue cases" {
  let a = make_finding(UnknownOrder, Error, Payment, "P", "O", "unknown")
  let b = make_finding(Underpaid, Warning, Order, "O", "O", "under")
  let queue = enqueue_findings(empty_review_queue(), [a, b], 1)
  let assigned = assign_case(queue, "CASE-1", "ops", 2)
  let active = transition_case(assigned, "CASE-1", Investigating, 2)
  let summary = review_summary(active, 10, 5)
  assert_eq(summary.open, 1)
  assert_eq(summary.investigating, 1)
  assert_eq(summary.unassigned, 1)
  assert_eq(summary.overdue, 2)
}

///|
test "automatic assignment uses finding code rule" {
  let a = make_finding(UnknownOrder, Error, Payment, "P", "O", "unknown")
  let b = make_finding(Underpaid, Warning, Order, "O", "O", "under")
  let queue = enqueue_findings(empty_review_queue(), [a, b], 1)
  let assigned = auto_assign(
    queue,
    [
      { code: UnknownOrder, owner: "integration", },
      { code: Underpaid, owner: "collections", },
    ],
    2,
  )
  assert_eq(cases_for_owner(assigned.cases, "integration").length(), 1)
  assert_eq(cases_for_owner(assigned.cases, "collections").length(), 1)
  assert_true(review_queue_is_consistent(assigned))
}

///|
test "quality profile accepts clean data" {
  let report = inspect_input_quality(clean_input(), default_policy(), 3)
  assert_true(report.ready)
  assert_eq(report.issues.length(), 0)
  assert_eq(report.orders.record_count, 1)
  assert_eq(report.payments.record_count, 1)
  assert_true(input_quality_report_is_consistent(report))
}

///|
test "quality profile reports duplicate blank and orphan data" {
  let input : LedgerInput = {
    orders: [
      {
        id: "",
        account_id: "",
        currency: "BAD",
        amount_minor: 0,
        created_day: -1,
        status: Paid,
      },
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
    payments: [
      {
        id: "",
        order_id: "",
        currency: "BAD",
        amount_minor: 0,
        received_day: 9,
        status: Failed,
      },
      {
        id: "P",
        order_id: "MISSING",
        currency: "CNY",
        amount_minor: 10,
        received_day: 1,
        status: Captured,
      },
    ],
    refunds: [],
    adjustments: [],
  }
  let report = inspect_input_quality(input, default_policy(), 5)
  assert_false(report.ready)
  assert_true(report.orders.blank_identifier_count > 0)
  assert_true(report.orders.duplicate_identifier_count > 0)
  assert_true(report.payments.blank_reference_count > 0)
  assert_true(report.payments.orphan_reference_count > 0)
  assert_true(report.payments.future_day_count > 0)
  assert_true(blocking_quality_issues(report).length() > 0)
}

///|
test "quality profile identifies missing refund and adjustment reasons" {
  let input : LedgerInput = {
    orders: [base_order("O", "team", 100, 1)],
    payments: [],
    refunds: [
      {
        id: "R",
        order_id: "O",
        currency: "CNY",
        amount_minor: 10,
        refunded_day: 2,
        reason: "",
      },
    ],
    adjustments: [
      {
        id: "A",
        order_id: "O",
        currency: "CNY",
        amount_minor: 10,
        day: 2,
        direction: Credit,
        reason: "",
      },
    ],
  }
  let report = inspect_input_quality(input, default_policy(), 3)
  let missing = quality_issues_for_code(report, MissingReason)
  assert_eq(missing.length(), 2)
  assert_eq(missing[0].severity, Warning)
  assert_eq(missing[1].severity, Warning)
  assert_true(input_quality_report_is_consistent(report))
}

///|
test "quality report rendering includes source and readiness" {
  let input : LedgerInput = {
    orders: [base_order("O", "team", 100, 10)],
    payments: [],
    refunds: [],
    adjustments: [],
  }
  let report = inspect_input_quality(input, default_policy(), 5)
  let rendered = render_quality_report(report)
  assert_true(rendered.contains("orders"))
  assert_true(rendered.contains("future_dated_record"))
  assert_true(rendered.contains("ready=true"))
}

///|
test "CSV exports quote commas quotes and newlines" {
  assert_eq(csv_escape("plain"), "plain")
  assert_eq(csv_escape("a,b"), "\"a,b\"")
  assert_eq(csv_escape("say \"yes\""), "\"say \"\"yes\"\"\"")
  assert_eq(csv_escape("first\nsecond"), "\"first\nsecond\"")
  let exported = render_findings_csv([
    make_finding(UnknownOrder, Error, Payment, "P,1", "O", "needs \"review\""),
  ])
  assert_true(exported.contains("\"P,1\""))
  assert_true(exported.contains("\"needs \"\"review\"\"\""))
  let generated = render_currency_totals_csv([])
  assert_true(export_is_safe_csv(generated))
}
