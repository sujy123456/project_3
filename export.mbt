///| Export helpers create plain-text artifacts suitable for audit attachments.

///|
pub fn csv_escape(value : String) -> String {
  if !(value.contains(",") || value.contains("\"") || value.contains("\n")) {
    return value
  }
  let mut escaped = "\""
  for char in value.to_array() {
    if char == '"' {
      escaped = escaped + "\"\""
    } else {
      escaped = escaped + char.to_string()
    }
  }
  escaped + "\""
}

///|
pub fn render_metrics_markdown(metrics : ResultMetrics) -> String {
  "# Reconciliation metrics\n\n" +
  "| Metric | Value |\n| --- | ---: |\n" +
  "| Expected minor units | \{metrics.expected_minor} |\n" +
  "| Captured minor units | \{metrics.captured_minor} |\n" +
  "| Refunded minor units | \{metrics.refunded_minor} |\n" +
  "| Outstanding minor units | \{metrics.outstanding_minor} |\n" +
  "| Settled orders | \{metrics.settled_orders} |\n" +
  "| Awaiting payment | \{metrics.awaiting_payment_orders} |\n" +
  "| Over-collected | \{metrics.over_collected_orders} |\n" +
  "| Refund risk | \{metrics.refund_risk_orders} |\n" +
  "| Errors | \{metrics.finding_metrics.error} |\n" +
  "| Warnings | \{metrics.finding_metrics.warning} |\n"
}

///|
pub fn render_code_counts_markdown(counts : Array[CodeCount]) -> String {
  let mut output = "# Finding counts\n\n| Code | Count |\n| --- | ---: |\n"
  for item in counts {
    output = output + "| \{finding_code_label(item.code)} | \{item.count} |\n"
  }
  output
}

///|
pub fn render_currency_totals_csv(totals : Array[CurrencyTotal]) -> String {
  let mut output = "currency,order_count,expected_minor,captured_minor,refunded_minor,outstanding_minor\n"
  for total in totals {
    output = output +
      "\{csv_escape(total.currency)},\{total.order_count},\{total.expected_minor},\{total.captured_minor},\{total.refunded_minor},\{total.outstanding_minor}\n"
  }
  output
}

///|
pub fn render_account_totals_csv(totals : Array[AccountTotal]) -> String {
  let mut output = "account_id,order_count,expected_minor,captured_minor,refunded_minor,outstanding_minor\n"
  for total in totals {
    output = output +
      "\{csv_escape(total.account_id)},\{total.order_count},\{total.expected_minor},\{total.captured_minor},\{total.refunded_minor},\{total.outstanding_minor}\n"
  }
  output
}

///|
pub fn render_age_buckets_csv(buckets : Array[AgeBucket]) -> String {
  let mut output = "age_bucket,order_count,outstanding_minor\n"
  for bucket in buckets {
    output = output +
      "\{csv_escape(bucket.label)},\{bucket.order_count},\{bucket.outstanding_minor}\n"
  }
  output
}

///|
pub fn render_findings_csv(findings : Array[Finding]) -> String {
  let mut output = "severity,code,record_kind,record_id,order_id,message\n"
  for finding in findings {
    let kind = match finding.record_kind {
      Order => "order"
      Payment => "payment"
      Refund => "refund"
      Adjustment => "adjustment"
    }
    output = output +
      "\{severity_label(finding.severity)},\{finding_code_label(finding.code)},\{kind},\{csv_escape(finding.record_id)},\{csv_escape(finding.order_id)},\{csv_escape(finding.message)}\n"
  }
  output
}

///|
pub fn render_review_queue_csv(queue : ReviewQueue) -> String {
  let mut output = "case_id,priority,state,owner,decision,record_id,order_id,code,note\n"
  for case in sort_cases_by_priority(queue.cases) {
    output = output +
      "\{csv_escape(case.case_id)},\{case.priority},\{review_state_label(case.state)},\{csv_escape(case.owner)},\{review_decision_label(case.decision)},\{csv_escape(case.finding.record_id)},\{csv_escape(case.finding.order_id)},\{finding_code_label(case.finding.code)},\{csv_escape(case.resolution_note)}\n"
  }
  output
}

///|
pub fn render_allocation_csv(plan : AllocationPlan) -> String {
  let mut output = "payment_id,order_id,currency,allocated_minor,state,note\n"
  for allocation in plan.allocations {
    output = output +
      "\{csv_escape(allocation.payment_id)},\{csv_escape(allocation.order_id)},\{csv_escape(allocation.currency)},\{allocation.allocated_minor},\{allocation_state_label(allocation.state)},\{csv_escape(allocation.note)}\n"
  }
  output
}

///|
pub fn render_quality_issues_csv(report : InputQualityReport) -> String {
  let mut output = "source,row_number,severity,code,record_id,order_id,message\n"
  for issue in report.issues {
    output = output +
      "\{source_kind_label(issue.source)},\{issue.row_number},\{severity_label(issue.severity)},\{quality_issue_code_label(issue.code)},\{csv_escape(issue.record_id)},\{csv_escape(issue.order_id)},\{csv_escape(issue.message)}\n"
  }
  output
}

///|
pub fn render_audit_bundle(
  input : LedgerInput,
  result : ReconciliationResult,
  current_day : Int,
) -> String {
  let metrics = result_metrics(result)
  let queue = queue_from_result(result, current_day)
  let allocation = allocate_payments(input, result)
  let quality = inspect_input_quality(input, default_policy(), current_day)
  render_metrics_markdown(metrics) +
  "\n" +
  render_code_counts_markdown(finding_code_counts(result.findings)) +
  "\n" +
  "## Review queue\n\n```\n" +
  render_review_queue(queue) +
  "```\n\n" +
  "## Allocation plan\n\n```\n" +
  render_allocation_plan(allocation) +
  "```\n\n" +
  "## Input quality\n\n```\n" +
  render_quality_report(quality) +
  "```\n"
}

///|
pub fn export_is_safe_csv(text : String) -> Bool {
  !text.contains("\r")
}
