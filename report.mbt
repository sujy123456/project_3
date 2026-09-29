///|
pub fn resolution_label(value : Resolution) -> String {
  match value {
    Settled => "settled"
    AwaitingPayment => "awaiting_payment"
    OverCollected => "over_collected"
    RefundRisk => "refund_risk"
    NeedsReview => "needs_review"
  }
}

///|
pub fn severity_label(value : Severity) -> String {
  match value {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
pub fn finding_code_label(value : FindingCode) -> String {
  match value {
    DuplicateOrderId => "duplicate_order_id"
    DuplicatePaymentId => "duplicate_payment_id"
    DuplicateRefundId => "duplicate_refund_id"
    DuplicateAdjustmentId => "duplicate_adjustment_id"
    InvalidAmount => "invalid_amount"
    InvalidCurrency => "invalid_currency"
    UnknownOrder => "unknown_order"
    CurrencyMismatch => "currency_mismatch"
    PaymentAfterDeadline => "payment_after_deadline"
    PaymentForCancelledOrder => "payment_for_cancelled_order"
    RefundExceedsPayment => "refund_exceeds_payment"
    Overpaid => "overpaid"
    Underpaid => "underpaid"
    OpenPastDue => "open_past_due"
    PaymentVoided => "payment_voided"
    MissingReference => "missing_reference"
  }
}

///|
pub fn render_summary(result : ReconciliationResult) -> String {
  let state = if result.valid { "PASS" } else { "REVIEW REQUIRED" }
  "LedgerWeave reconciliation: \{state}\norders=\{result.balances.length()} findings=\{result.findings.length()}"
}

///|
pub fn render_balances(result : ReconciliationResult) -> String {
  let mut out = "ORDER | EXPECTED | CAPTURED | REFUNDED | OUTSTANDING | RESOLUTION\n"
  for balance in result.balances {
    out = out +
      "\{balance.order_id} | \{balance.expected_minor} | \{balance.captured_minor} | \{balance.refunded_minor} | \{balance.outstanding_minor} | \{resolution_label(balance.resolution)}\n"
  }
  out
}

///|
pub fn render_findings(result : ReconciliationResult) -> String {
  let mut out = "SEVERITY | CODE | RECORD | MESSAGE\n"
  for finding in result.findings {
    out = out +
      "\{severity_label(finding.severity)} | \{finding_code_label(finding.code)} | \{finding.record_id} | \{finding.message}\n"
  }
  out
}
