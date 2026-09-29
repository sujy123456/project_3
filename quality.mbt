///| Input-quality profiling validates import readiness before reconciliation.

///|
pub(all) enum SourceKind {
  OrdersSource
  PaymentsSource
  RefundsSource
  AdjustmentsSource
} derive(Debug, Eq)

///|
pub(all) enum QualityIssueCode {
  BlankIdentifier
  BlankAccount
  BlankReference
  UnsupportedCurrency
  NonPositiveAmount
  NegativeDay
  DuplicateIdentifier
  OrphanReference
  MissingReason
  InvalidStatusCombination
  FutureDatedRecord
} derive(Debug, Eq)

///|
pub(all) struct QualityIssue {
  source : SourceKind
  row_number : Int
  record_id : String
  order_id : String
  code : QualityIssueCode
  severity : Severity
  message : String
} derive(Debug, Eq)

///|
pub(all) struct SourceProfile {
  source : SourceKind
  record_count : Int
  blank_identifier_count : Int
  duplicate_identifier_count : Int
  invalid_amount_count : Int
  blank_reference_count : Int
  orphan_reference_count : Int
  invalid_currency_count : Int
  future_day_count : Int
} derive(Debug, Eq)

///|
pub(all) struct InputQualityReport {
  orders : SourceProfile
  payments : SourceProfile
  refunds : SourceProfile
  adjustments : SourceProfile
  issues : Array[QualityIssue]
  ready : Bool
} derive(Debug, Eq)

///|
pub fn source_kind_label(source : SourceKind) -> String {
  match source {
    OrdersSource => "orders"
    PaymentsSource => "payments"
    RefundsSource => "refunds"
    AdjustmentsSource => "adjustments"
  }
}

///|
pub fn quality_issue_code_label(code : QualityIssueCode) -> String {
  match code {
    BlankIdentifier => "blank_identifier"
    BlankAccount => "blank_account"
    BlankReference => "blank_reference"
    UnsupportedCurrency => "unsupported_currency"
    NonPositiveAmount => "non_positive_amount"
    NegativeDay => "negative_day"
    DuplicateIdentifier => "duplicate_identifier"
    OrphanReference => "orphan_reference"
    MissingReason => "missing_reason"
    InvalidStatusCombination => "invalid_status_combination"
    FutureDatedRecord => "future_dated_record"
  }
}

///|
pub fn empty_source_profile(source : SourceKind) -> SourceProfile {
  {
    source,
    record_count: 0,
    blank_identifier_count: 0,
    duplicate_identifier_count: 0,
    invalid_amount_count: 0,
    blank_reference_count: 0,
    orphan_reference_count: 0,
    invalid_currency_count: 0,
    future_day_count: 0,
  }
}

///|
pub fn empty_input_quality_report() -> InputQualityReport {
  {
    orders: empty_source_profile(OrdersSource),
    payments: empty_source_profile(PaymentsSource),
    refunds: empty_source_profile(RefundsSource),
    adjustments: empty_source_profile(AdjustmentsSource),
    issues: [],
    ready: true,
  }
}

///|
pub fn quality_severity(code : QualityIssueCode) -> Severity {
  match code {
    BlankIdentifier => Error
    BlankAccount => Warning
    BlankReference => Error
    UnsupportedCurrency => Error
    NonPositiveAmount => Error
    NegativeDay => Error
    DuplicateIdentifier => Error
    OrphanReference => Error
    MissingReason => Warning
    InvalidStatusCombination => Warning
    FutureDatedRecord => Warning
  }
}

///|
pub fn quality_issue(
  source : SourceKind,
  row_number : Int,
  record_id : String,
  order_id : String,
  code : QualityIssueCode,
  message : String,
) -> QualityIssue {
  {
    source,
    row_number,
    record_id,
    order_id,
    code,
    severity: quality_severity(code),
    message,
  }
}

///|
fn add_issue(issues : Array[QualityIssue], issue : QualityIssue) -> Unit {
  issues.push(issue)
}

///|
fn allowed_currency(policy : Policy, currency : String) -> Bool {
  contains_string(policy.allowed_currencies, currency)
}

///|
fn duplicate_position(ids : Array[String], id : String, position : Int) -> Bool {
  if is_blank(id) {
    return false
  }
  for index = 0; index < position; index = index + 1 {
    if ids[index] == id {
      return true
    }
  }
  false
}

///|
fn update_profile_for_issue(
  profile : SourceProfile,
  code : QualityIssueCode,
) -> SourceProfile {
  match code {
    BlankIdentifier =>
      { ..profile, blank_identifier_count: profile.blank_identifier_count + 1, }
    BlankReference =>
      { ..profile, blank_reference_count: profile.blank_reference_count + 1, }
    NonPositiveAmount =>
      { ..profile, invalid_amount_count: profile.invalid_amount_count + 1, }
    DuplicateIdentifier =>
      {
        ..profile,
        duplicate_identifier_count: profile.duplicate_identifier_count + 1,
      }
    OrphanReference =>
      { ..profile, orphan_reference_count: profile.orphan_reference_count + 1, }
    UnsupportedCurrency =>
      { ..profile, invalid_currency_count: profile.invalid_currency_count + 1, }
    FutureDatedRecord =>
      { ..profile, future_day_count: profile.future_day_count + 1, }
    _ => profile
  }
}

///|
fn record_issue(
  profile : SourceProfile,
  issues : Array[QualityIssue],
  issue : QualityIssue,
) -> SourceProfile {
  add_issue(issues, issue)
  update_profile_for_issue(profile, issue.code)
}

///|
fn inspect_orders(
  input : LedgerInput,
  policy : Policy,
  current_day : Int,
  issues : Array[QualityIssue],
) -> SourceProfile {
  let mut profile = {
    ..empty_source_profile(OrdersSource),
    record_count: input.orders.length(),
  }
  let ids : Array[String] = []
  for order in input.orders {
    ids.push(order.id)
  }
  for index = 0; index < input.orders.length(); index = index + 1 {
    let order = input.orders[index]
    let row = index + 2
    if is_blank(order.id) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          OrdersSource,
          row,
          order.id,
          order.id,
          BlankIdentifier,
          "order identifier is blank",
        ),
      )
    }
    if duplicate_position(ids, order.id, index) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          OrdersSource,
          row,
          order.id,
          order.id,
          DuplicateIdentifier,
          "order identifier duplicates an earlier row",
        ),
      )
    }
    if is_blank(order.account_id) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          OrdersSource,
          row,
          order.id,
          order.id,
          BlankAccount,
          "order account is blank",
        ),
      )
    }
    if order.amount_minor <= 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          OrdersSource,
          row,
          order.id,
          order.id,
          NonPositiveAmount,
          "order amount must be positive",
        ),
      )
    }
    if !allowed_currency(policy, order.currency) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          OrdersSource,
          row,
          order.id,
          order.id,
          UnsupportedCurrency,
          "order currency is not allowed",
        ),
      )
    }
    if order.created_day < 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          OrdersSource,
          row,
          order.id,
          order.id,
          NegativeDay,
          "order day cannot be negative",
        ),
      )
    }
    if order.created_day > current_day {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          OrdersSource,
          row,
          order.id,
          order.id,
          FutureDatedRecord,
          "order is dated after reconciliation day",
        ),
      )
    }
    if order.status == Refunded && order.amount_minor <= 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          OrdersSource,
          row,
          order.id,
          order.id,
          InvalidStatusCombination,
          "refunded order needs a positive original amount",
        ),
      )
    }
  }
  profile
}

///|
fn inspect_payments(
  input : LedgerInput,
  policy : Policy,
  current_day : Int,
  issues : Array[QualityIssue],
) -> SourceProfile {
  let mut profile = {
    ..empty_source_profile(PaymentsSource),
    record_count: input.payments.length(),
  }
  let ids : Array[String] = []
  for payment in input.payments {
    ids.push(payment.id)
  }
  for index = 0; index < input.payments.length(); index = index + 1 {
    let payment = input.payments[index]
    let row = index + 2
    if is_blank(payment.id) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          BlankIdentifier,
          "payment identifier is blank",
        ),
      )
    }
    if duplicate_position(ids, payment.id, index) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          DuplicateIdentifier,
          "payment identifier duplicates an earlier row",
        ),
      )
    }
    if is_blank(payment.order_id) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          BlankReference,
          "payment order reference is blank",
        ),
      )
    } else if find_order(input, payment.order_id) is None {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          OrphanReference,
          "payment order reference does not exist",
        ),
      )
    }
    if payment.amount_minor <= 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          NonPositiveAmount,
          "payment amount must be positive",
        ),
      )
    }
    if !allowed_currency(policy, payment.currency) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          UnsupportedCurrency,
          "payment currency is not allowed",
        ),
      )
    }
    if payment.received_day < 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          NegativeDay,
          "payment day cannot be negative",
        ),
      )
    }
    if payment.received_day > current_day {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          FutureDatedRecord,
          "payment is dated after reconciliation day",
        ),
      )
    }
    if payment.status == Failed && payment.amount_minor > 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          PaymentsSource,
          row,
          payment.id,
          payment.order_id,
          InvalidStatusCombination,
          "failed payment has a non-zero amount",
        ),
      )
    }
  }
  profile
}

///|
fn inspect_refunds(
  input : LedgerInput,
  policy : Policy,
  current_day : Int,
  issues : Array[QualityIssue],
) -> SourceProfile {
  let mut profile = {
    ..empty_source_profile(RefundsSource),
    record_count: input.refunds.length(),
  }
  let ids : Array[String] = []
  for refund in input.refunds {
    ids.push(refund.id)
  }
  for index = 0; index < input.refunds.length(); index = index + 1 {
    let refund = input.refunds[index]
    let row = index + 2
    if is_blank(refund.id) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          BlankIdentifier,
          "refund identifier is blank",
        ),
      )
    }
    if duplicate_position(ids, refund.id, index) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          DuplicateIdentifier,
          "refund identifier duplicates an earlier row",
        ),
      )
    }
    if is_blank(refund.order_id) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          BlankReference,
          "refund order reference is blank",
        ),
      )
    } else if find_order(input, refund.order_id) is None {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          OrphanReference,
          "refund order reference does not exist",
        ),
      )
    }
    if refund.amount_minor <= 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          NonPositiveAmount,
          "refund amount must be positive",
        ),
      )
    }
    if !allowed_currency(policy, refund.currency) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          UnsupportedCurrency,
          "refund currency is not allowed",
        ),
      )
    }
    if refund.refunded_day < 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          NegativeDay,
          "refund day cannot be negative",
        ),
      )
    }
    if refund.refunded_day > current_day {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          FutureDatedRecord,
          "refund is dated after reconciliation day",
        ),
      )
    }
    if is_blank(refund.reason) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          RefundsSource,
          row,
          refund.id,
          refund.order_id,
          MissingReason,
          "refund reason is blank",
        ),
      )
    }
  }
  profile
}

///|
fn inspect_adjustments(
  input : LedgerInput,
  policy : Policy,
  current_day : Int,
  issues : Array[QualityIssue],
) -> SourceProfile {
  let mut profile = {
    ..empty_source_profile(AdjustmentsSource),
    record_count: input.adjustments.length(),
  }
  let ids : Array[String] = []
  for adjustment in input.adjustments {
    ids.push(adjustment.id)
  }
  for index = 0; index < input.adjustments.length(); index = index + 1 {
    let adjustment = input.adjustments[index]
    let row = index + 2
    if is_blank(adjustment.id) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          BlankIdentifier,
          "adjustment identifier is blank",
        ),
      )
    }
    if duplicate_position(ids, adjustment.id, index) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          DuplicateIdentifier,
          "adjustment identifier duplicates an earlier row",
        ),
      )
    }
    if is_blank(adjustment.order_id) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          BlankReference,
          "adjustment order reference is blank",
        ),
      )
    } else if find_order(input, adjustment.order_id) is None {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          OrphanReference,
          "adjustment order reference does not exist",
        ),
      )
    }
    if adjustment.amount_minor <= 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          NonPositiveAmount,
          "adjustment amount must be positive",
        ),
      )
    }
    if !allowed_currency(policy, adjustment.currency) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          UnsupportedCurrency,
          "adjustment currency is not allowed",
        ),
      )
    }
    if adjustment.day < 0 {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          NegativeDay,
          "adjustment day cannot be negative",
        ),
      )
    }
    if adjustment.day > current_day {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          FutureDatedRecord,
          "adjustment is dated after reconciliation day",
        ),
      )
    }
    if is_blank(adjustment.reason) {
      profile = record_issue(
        profile,
        issues,
        quality_issue(
          AdjustmentsSource,
          row,
          adjustment.id,
          adjustment.order_id,
          MissingReason,
          "adjustment reason is blank",
        ),
      )
    }
  }
  profile
}

///|
pub fn inspect_input_quality(
  input : LedgerInput,
  policy : Policy,
  current_day : Int,
) -> InputQualityReport {
  let issues : Array[QualityIssue] = []
  let orders = inspect_orders(input, policy, current_day, issues)
  let payments = inspect_payments(input, policy, current_day, issues)
  let refunds = inspect_refunds(input, policy, current_day, issues)
  let adjustments = inspect_adjustments(input, policy, current_day, issues)
  let mut ready = true
  for issue in issues {
    if issue.severity == Error {
      ready = false
    }
  }
  { orders, payments, refunds, adjustments, issues, ready, }
}

///|
pub fn quality_issues_for_source(
  report : InputQualityReport,
  source : SourceKind,
) -> Array[QualityIssue] {
  let selected : Array[QualityIssue] = []
  for issue in report.issues {
    if issue.source == source {
      selected.push(issue)
    }
  }
  selected
}

///|
pub fn quality_issues_for_code(
  report : InputQualityReport,
  code : QualityIssueCode,
) -> Array[QualityIssue] {
  let selected : Array[QualityIssue] = []
  for issue in report.issues {
    if issue.code == code {
      selected.push(issue)
    }
  }
  selected
}

///|
pub fn blocking_quality_issues(
  report : InputQualityReport,
) -> Array[QualityIssue] {
  let selected : Array[QualityIssue] = []
  for issue in report.issues {
    if issue.severity == Error {
      selected.push(issue)
    }
  }
  selected
}

///|
pub fn render_quality_report(report : InputQualityReport) -> String {
  let mut output = "SOURCE | ROW | SEVERITY | CODE | RECORD | MESSAGE\n"
  for issue in report.issues {
    output = output +
      "\{source_kind_label(issue.source)} | \{issue.row_number} | \{severity_label(issue.severity)} | \{quality_issue_code_label(issue.code)} | \{issue.record_id} | \{issue.message}\n"
  }
  output + "ready=\{report.ready} issues=\{report.issues.length()}"
}

///|
pub fn source_profile_is_consistent(profile : SourceProfile) -> Bool {
  profile.record_count >= 0 &&
  profile.blank_identifier_count >= 0 &&
  profile.duplicate_identifier_count >= 0 &&
  profile.invalid_amount_count >= 0 &&
  profile.blank_reference_count >= 0 &&
  profile.orphan_reference_count >= 0 &&
  profile.invalid_currency_count >= 0 &&
  profile.future_day_count >= 0
}

///|
pub fn input_quality_report_is_consistent(report : InputQualityReport) -> Bool {
  if !source_profile_is_consistent(report.orders) ||
    !source_profile_is_consistent(report.payments) ||
    !source_profile_is_consistent(report.refunds) ||
    !source_profile_is_consistent(report.adjustments) {
    return false
  }
  let mut expected_ready = true
  for issue in report.issues {
    if issue.row_number < 2 || is_blank(issue.message) {
      return false
    }
    if issue.severity == Error {
      expected_ready = false
    }
  }
  report.ready == expected_ready
}
