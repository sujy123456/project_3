///| Analytical views for reconciliation runs. All functions are deterministic.

///|
pub(all) struct FindingMetrics {
  total : Int
  info : Int
  warning : Int
  error : Int
  blocking : Int
} derive(Debug, Eq)

///|
pub(all) struct CodeCount {
  code : FindingCode
  count : Int
} derive(Debug, Eq)

///|
pub(all) struct ResolutionCount {
  resolution : Resolution
  count : Int
} derive(Debug, Eq)

///|
pub(all) struct CurrencyTotal {
  currency : String
  order_count : Int
  expected_minor : Int
  captured_minor : Int
  refunded_minor : Int
  outstanding_minor : Int
} derive(Debug, Eq)

///|
pub(all) struct AccountTotal {
  account_id : String
  order_count : Int
  expected_minor : Int
  captured_minor : Int
  refunded_minor : Int
  outstanding_minor : Int
} derive(Debug, Eq)

///|
pub(all) struct AgeBucket {
  label : String
  order_count : Int
  outstanding_minor : Int
} derive(Debug, Eq)

///|
pub(all) struct ResultMetrics {
  finding_metrics : FindingMetrics
  settled_orders : Int
  awaiting_payment_orders : Int
  over_collected_orders : Int
  refund_risk_orders : Int
  review_orders : Int
  expected_minor : Int
  captured_minor : Int
  refunded_minor : Int
  outstanding_minor : Int
} derive(Debug, Eq)

///|
pub(all) struct FindingQuery {
  minimum_severity : Severity
  code : FindingCode?
  order_id : String?
  record_kind : RecordKind?
} derive(Debug, Eq)

///|
pub fn empty_finding_metrics() -> FindingMetrics {
  { total: 0, info: 0, warning: 0, error: 0, blocking: 0, }
}

///|
pub fn empty_result_metrics() -> ResultMetrics {
  {
    finding_metrics: empty_finding_metrics(),
    settled_orders: 0,
    awaiting_payment_orders: 0,
    over_collected_orders: 0,
    refund_risk_orders: 0,
    review_orders: 0,
    expected_minor: 0,
    captured_minor: 0,
    refunded_minor: 0,
    outstanding_minor: 0,
  }
}

///|
pub fn severity_rank(severity : Severity) -> Int {
  match severity {
    Info => 1
    Warning => 2
    Error => 3
  }
}

///|
pub fn resolution_rank(resolution : Resolution) -> Int {
  match resolution {
    Settled => 1
    AwaitingPayment => 2
    OverCollected => 3
    RefundRisk => 4
    NeedsReview => 5
  }
}

///|
pub fn finding_metrics(findings : Array[Finding]) -> FindingMetrics {
  let mut metrics = empty_finding_metrics()
  for finding in findings {
    metrics = { ..metrics, total: metrics.total + 1, }
    match finding.severity {
      Info => metrics = { ..metrics, info: metrics.info + 1, }
      Warning => metrics = { ..metrics, warning: metrics.warning + 1, }
      Error =>
        metrics = {
          ..metrics,
          error: metrics.error + 1,
          blocking: metrics.blocking + 1,
        }
    }
  }
  metrics
}

///|
fn add_balance_metrics(
  metrics : ResultMetrics,
  balance : OrderBalance,
) -> ResultMetrics {
  let mut next = {
    ..metrics,
    expected_minor: metrics.expected_minor + balance.expected_minor,
    captured_minor: metrics.captured_minor + balance.captured_minor,
    refunded_minor: metrics.refunded_minor + balance.refunded_minor,
    outstanding_minor: metrics.outstanding_minor + balance.outstanding_minor,
  }
  match balance.resolution {
    Settled => next = { ..next, settled_orders: next.settled_orders + 1, }
    AwaitingPayment =>
      next = {
        ..next,
        awaiting_payment_orders: next.awaiting_payment_orders + 1,
      }
    OverCollected =>
      next = { ..next, over_collected_orders: next.over_collected_orders + 1, }
    RefundRisk =>
      next = { ..next, refund_risk_orders: next.refund_risk_orders + 1, }
    NeedsReview => next = { ..next, review_orders: next.review_orders + 1, }
  }
  next
}

///|
pub fn result_metrics(result : ReconciliationResult) -> ResultMetrics {
  let mut metrics = {
    ..empty_result_metrics(),
    finding_metrics: finding_metrics(result.findings),
  }
  for balance in result.balances {
    metrics = add_balance_metrics(metrics, balance)
  }
  metrics
}

///|
pub fn count_findings_by_code(
  findings : Array[Finding],
  code : FindingCode,
) -> Int {
  let mut count = 0
  for finding in findings {
    if finding.code == code {
      count = count + 1
    }
  }
  count
}

///|
pub fn finding_code_counts(findings : Array[Finding]) -> Array[CodeCount] {
  let values : Array[FindingCode] = [
    DuplicateOrderId,
    DuplicatePaymentId,
    DuplicateRefundId,
    DuplicateAdjustmentId,
    InvalidAmount,
    InvalidCurrency,
    UnknownOrder,
    CurrencyMismatch,
    PaymentAfterDeadline,
    PaymentForCancelledOrder,
    RefundExceedsPayment,
    Overpaid,
    Underpaid,
    OpenPastDue,
    PaymentVoided,
    MissingReference,
  ]
  let counts : Array[CodeCount] = []
  for code in values {
    let count = count_findings_by_code(findings, code)
    if count > 0 {
      counts.push({ code, count, })
    }
  }
  counts
}

///|
pub fn count_balances_by_resolution(
  balances : Array[OrderBalance],
  resolution : Resolution,
) -> Int {
  let mut count = 0
  for balance in balances {
    if balance.resolution == resolution {
      count = count + 1
    }
  }
  count
}

///|
pub fn resolution_counts(
  result : ReconciliationResult,
) -> Array[ResolutionCount] {
  let values : Array[Resolution] = [
    Settled,
    AwaitingPayment,
    OverCollected,
    RefundRisk,
    NeedsReview,
  ]
  let counts : Array[ResolutionCount] = []
  for resolution in values {
    let count = count_balances_by_resolution(result.balances, resolution)
    if count > 0 {
      counts.push({ resolution, count, })
    }
  }
  counts
}

///|
fn query_matches_finding(query : FindingQuery, finding : Finding) -> Bool {
  if severity_rank(finding.severity) < severity_rank(query.minimum_severity) {
    return false
  }
  match query.code {
    Some(code) => if finding.code != code { return false }
    None => ()
  }
  match query.order_id {
    Some(order_id) => if finding.order_id != order_id { return false }
    None => ()
  }
  match query.record_kind {
    Some(kind) => if finding.record_kind != kind { return false }
    None => ()
  }
  true
}

///|
pub fn filter_findings(
  findings : Array[Finding],
  query : FindingQuery,
) -> Array[Finding] {
  let filtered : Array[Finding] = []
  for finding in findings {
    if query_matches_finding(query, finding) {
      filtered.push(finding)
    }
  }
  filtered
}

///|
pub fn error_findings(findings : Array[Finding]) -> Array[Finding] {
  filter_findings(findings, {
    minimum_severity: Error,
    code: None,
    order_id: None,
    record_kind: None,
  })
}

///|
pub fn warning_or_higher_findings(findings : Array[Finding]) -> Array[Finding] {
  filter_findings(findings, {
    minimum_severity: Warning,
    code: None,
    order_id: None,
    record_kind: None,
  })
}

///|
pub fn findings_for_order(
  findings : Array[Finding],
  order_id : String,
) -> Array[Finding] {
  filter_findings(findings, {
    minimum_severity: Info,
    code: None,
    order_id: Some(order_id),
    record_kind: None,
  })
}

///|
pub fn findings_for_kind(
  findings : Array[Finding],
  kind : RecordKind,
) -> Array[Finding] {
  filter_findings(findings, {
    minimum_severity: Info,
    code: None,
    order_id: None,
    record_kind: Some(kind),
  })
}

///|
pub fn balances_above_outstanding(
  balances : Array[OrderBalance],
  threshold_minor : Int,
) -> Array[OrderBalance] {
  let selected : Array[OrderBalance] = []
  for balance in balances {
    if balance.outstanding_minor > threshold_minor {
      selected.push(balance)
    }
  }
  selected
}

///|
pub fn balances_below_outstanding(
  balances : Array[OrderBalance],
  threshold_minor : Int,
) -> Array[OrderBalance] {
  let selected : Array[OrderBalance] = []
  for balance in balances {
    if balance.outstanding_minor < threshold_minor {
      selected.push(balance)
    }
  }
  selected
}

///|
pub fn settled_balances(balances : Array[OrderBalance]) -> Array[OrderBalance] {
  let selected : Array[OrderBalance] = []
  for balance in balances {
    if balance.resolution == Settled {
      selected.push(balance)
    }
  }
  selected
}

///|
fn currency_position(totals : Array[CurrencyTotal], currency : String) -> Int {
  for index = 0; index < totals.length(); index = index + 1 {
    if totals[index].currency == currency {
      return index
    }
  }
  -1
}

///|
pub fn totals_by_currency(
  input : LedgerInput,
  result : ReconciliationResult,
) -> Array[CurrencyTotal] {
  let totals : Array[CurrencyTotal] = []
  for order in input.orders {
    match find_balance(result.balances, order.id) {
      None => ()
      Some(balance) => {
        let index = currency_position(totals, order.currency)
        if index < 0 {
          totals.push({
            currency: order.currency,
            order_count: 1,
            expected_minor: balance.expected_minor,
            captured_minor: balance.captured_minor,
            refunded_minor: balance.refunded_minor,
            outstanding_minor: balance.outstanding_minor,
          })
        } else {
          let current = totals[index]
          totals[index] = {
            ..current,
            order_count: current.order_count + 1,
            expected_minor: current.expected_minor + balance.expected_minor,
            captured_minor: current.captured_minor + balance.captured_minor,
            refunded_minor: current.refunded_minor + balance.refunded_minor,
            outstanding_minor: current.outstanding_minor +
            balance.outstanding_minor,
          }
        }
      }
    }
  }
  totals
}

///|
fn account_position(totals : Array[AccountTotal], account_id : String) -> Int {
  for index = 0; index < totals.length(); index = index + 1 {
    if totals[index].account_id == account_id {
      return index
    }
  }
  -1
}

///|
pub fn totals_by_account(
  input : LedgerInput,
  result : ReconciliationResult,
) -> Array[AccountTotal] {
  let totals : Array[AccountTotal] = []
  for order in input.orders {
    match find_balance(result.balances, order.id) {
      None => ()
      Some(balance) => {
        let index = account_position(totals, order.account_id)
        if index < 0 {
          totals.push({
            account_id: order.account_id,
            order_count: 1,
            expected_minor: balance.expected_minor,
            captured_minor: balance.captured_minor,
            refunded_minor: balance.refunded_minor,
            outstanding_minor: balance.outstanding_minor,
          })
        } else {
          let current = totals[index]
          totals[index] = {
            ..current,
            order_count: current.order_count + 1,
            expected_minor: current.expected_minor + balance.expected_minor,
            captured_minor: current.captured_minor + balance.captured_minor,
            refunded_minor: current.refunded_minor + balance.refunded_minor,
            outstanding_minor: current.outstanding_minor +
            balance.outstanding_minor,
          }
        }
      }
    }
  }
  totals
}

///|
pub fn find_balance(
  balances : Array[OrderBalance],
  order_id : String,
) -> OrderBalance? {
  for balance in balances {
    if balance.order_id == order_id {
      return Some(balance)
    }
  }
  None
}

///|
pub fn max_outstanding_balance(balances : Array[OrderBalance]) -> OrderBalance? {
  if balances.is_empty() {
    return None
  }
  let mut largest = balances[0]
  for balance in balances {
    if balance.outstanding_minor > largest.outstanding_minor {
      largest = balance
    }
  }
  Some(largest)
}

///|
pub fn min_outstanding_balance(balances : Array[OrderBalance]) -> OrderBalance? {
  if balances.is_empty() {
    return None
  }
  let mut smallest = balances[0]
  for balance in balances {
    if balance.outstanding_minor < smallest.outstanding_minor {
      smallest = balance
    }
  }
  Some(smallest)
}

///|
pub fn sort_balances_by_outstanding(
  balances : Array[OrderBalance],
) -> Array[OrderBalance] {
  let sorted = balances.copy()
  for outer = 0; outer < sorted.length(); outer = outer + 1 {
    for inner = 0; inner + 1 < sorted.length() - outer; inner = inner + 1 {
      if sorted[inner].outstanding_minor < sorted[inner + 1].outstanding_minor {
        let saved = sorted[inner]
        sorted[inner] = sorted[inner + 1]
        sorted[inner + 1] = saved
      }
    }
  }
  sorted
}

///|
pub fn sort_findings_by_severity(findings : Array[Finding]) -> Array[Finding] {
  let sorted = findings.copy()
  for outer = 0; outer < sorted.length(); outer = outer + 1 {
    for inner = 0; inner + 1 < sorted.length() - outer; inner = inner + 1 {
      if severity_rank(sorted[inner].severity) <
        severity_rank(sorted[inner + 1].severity) {
        let saved = sorted[inner]
        sorted[inner] = sorted[inner + 1]
        sorted[inner + 1] = saved
      }
    }
  }
  sorted
}

///|
pub fn balance_age(
  input : LedgerInput,
  order_id : String,
  current_day : Int,
) -> Int? {
  match find_order(input, order_id) {
    None => None
    Some(order) =>
      Some(
        if current_day > order.created_day {
          current_day - order.created_day
        } else {
          0
        },
      )
  }
}

///|
pub fn age_bucket_label(age_days : Int) -> String {
  if age_days < 0 {
    "invalid"
  } else if age_days <= 7 {
    "0-7"
  } else if age_days <= 30 {
    "8-30"
  } else if age_days <= 60 {
    "31-60"
  } else {
    "61+"
  }
}

///|
fn bucket_position(buckets : Array[AgeBucket], label : String) -> Int {
  for index = 0; index < buckets.length(); index = index + 1 {
    if buckets[index].label == label {
      return index
    }
  }
  -1
}

///|
pub fn outstanding_by_age(
  input : LedgerInput,
  result : ReconciliationResult,
  current_day : Int,
) -> Array[AgeBucket] {
  let buckets : Array[AgeBucket] = []
  for balance in result.balances {
    if balance.outstanding_minor <= 0 {
      continue
    }
    match balance_age(input, balance.order_id, current_day) {
      None => ()
      Some(age) => {
        let label = age_bucket_label(age)
        let index = bucket_position(buckets, label)
        if index < 0 {
          buckets.push({
            label,
            order_count: 1,
            outstanding_minor: balance.outstanding_minor,
          })
        } else {
          let bucket = buckets[index]
          buckets[index] = {
            ..bucket,
            order_count: bucket.order_count + 1,
            outstanding_minor: bucket.outstanding_minor +
            balance.outstanding_minor,
          }
        }
      }
    }
  }
  buckets
}

///|
pub fn quality_score(result : ReconciliationResult) -> Int {
  let metrics = result_metrics(result)
  let raw = 100 -
    metrics.finding_metrics.error * 20 -
    metrics.finding_metrics.warning * 5 -
    metrics.finding_metrics.info
  if raw < 0 {
    0
  } else {
    raw
  }
}

///|
pub fn is_healthy(result : ReconciliationResult) -> Bool {
  result.valid && quality_score(result) >= 90
}
