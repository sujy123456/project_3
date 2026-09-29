///|
fn has_duplicate(ids : Array[String], id : String) -> Bool {
  count_string(ids, id) > 1
}

///|
fn valid_currency(policy : Policy, currency : String) -> Bool {
  contains_string(policy.allowed_currencies, currency)
}

///|
fn validate_orders(
  input : LedgerInput,
  policy : Policy,
  findings : Array[Finding],
) -> Unit {
  let ids : Array[String] = []
  for order in input.orders {
    ids.push(order.id)
  }
  for order in input.orders {
    if is_blank(order.id) {
      findings.push(
        make_finding(
          MissingReference,
          Error,
          Order,
          order.id,
          order.id,
          "order id is required",
        ),
      )
    }
    if has_duplicate(ids, order.id) {
      findings.push(
        make_finding(
          DuplicateOrderId,
          Error,
          Order,
          order.id,
          order.id,
          "order id appears more than once",
        ),
      )
    }
    if order.amount_minor <= 0 {
      findings.push(
        make_finding(
          InvalidAmount,
          Error,
          Order,
          order.id,
          order.id,
          "order amount must be positive",
        ),
      )
    }
    if !valid_currency(policy, order.currency) {
      findings.push(
        make_finding(
          InvalidCurrency,
          Error,
          Order,
          order.id,
          order.id,
          "order currency is not allowed by policy",
        ),
      )
    }
  }
}

///|
fn validate_payments(
  input : LedgerInput,
  policy : Policy,
  findings : Array[Finding],
) -> Unit {
  let ids : Array[String] = []
  for payment in input.payments {
    ids.push(payment.id)
  }
  for payment in input.payments {
    if has_duplicate(ids, payment.id) {
      findings.push(
        make_finding(
          DuplicatePaymentId,
          Error,
          Payment,
          payment.id,
          payment.order_id,
          "payment id appears more than once",
        ),
      )
    }
    if payment.amount_minor <= 0 {
      findings.push(
        make_finding(
          InvalidAmount,
          Error,
          Payment,
          payment.id,
          payment.order_id,
          "payment amount must be positive",
        ),
      )
    }
    match find_order(input, payment.order_id) {
      None =>
        findings.push(
          make_finding(
            UnknownOrder,
            Error,
            Payment,
            payment.id,
            payment.order_id,
            "payment references an unknown order",
          ),
        )
      Some(order) => {
        if order.currency != payment.currency {
          findings.push(
            make_finding(
              CurrencyMismatch,
              Error,
              Payment,
              payment.id,
              payment.order_id,
              "payment currency differs from order currency",
            ),
          )
        }
        if payment.received_day - order.created_day >
          policy.max_payment_lag_days {
          findings.push(
            make_finding(
              PaymentAfterDeadline,
              Warning,
              Payment,
              payment.id,
              payment.order_id,
              "payment arrived after the configured payment window",
            ),
          )
        }
        if order.status == Cancelled && !policy.permit_cancelled_payment {
          findings.push(
            make_finding(
              PaymentForCancelledOrder,
              Error,
              Payment,
              payment.id,
              payment.order_id,
              "captured payment belongs to a cancelled order",
            ),
          )
        }
      }
    }
    if payment.status == Voided {
      findings.push(
        make_finding(
          PaymentVoided,
          Info,
          Payment,
          payment.id,
          payment.order_id,
          "voided payment is excluded from captured total",
        ),
      )
    }
  }
}

///|
fn validate_refunds(
  input : LedgerInput,
  policy : Policy,
  findings : Array[Finding],
) -> Unit {
  let ids : Array[String] = []
  for refund in input.refunds {
    ids.push(refund.id)
  }
  for refund in input.refunds {
    if has_duplicate(ids, refund.id) {
      findings.push(
        make_finding(
          DuplicateRefundId,
          Error,
          Refund,
          refund.id,
          refund.order_id,
          "refund id appears more than once",
        ),
      )
    }
    if refund.amount_minor <= 0 {
      findings.push(
        make_finding(
          InvalidAmount,
          Error,
          Refund,
          refund.id,
          refund.order_id,
          "refund amount must be positive",
        ),
      )
    }
    match find_order(input, refund.order_id) {
      None =>
        findings.push(
          make_finding(
            UnknownOrder,
            Error,
            Refund,
            refund.id,
            refund.order_id,
            "refund references an unknown order",
          ),
        )
      Some(order) =>
        if order.currency != refund.currency {
          findings.push(
            make_finding(
              CurrencyMismatch,
              Error,
              Refund,
              refund.id,
              refund.order_id,
              "refund currency differs from order currency",
            ),
          )
        }
    }
  }
  ignore(policy)
}

///|
fn validate_adjustments(
  input : LedgerInput,
  policy : Policy,
  findings : Array[Finding],
) -> Unit {
  let ids : Array[String] = []
  for adjustment in input.adjustments {
    ids.push(adjustment.id)
  }
  for adjustment in input.adjustments {
    if has_duplicate(ids, adjustment.id) {
      findings.push(
        make_finding(
          DuplicateAdjustmentId,
          Error,
          Adjustment,
          adjustment.id,
          adjustment.order_id,
          "adjustment id appears more than once",
        ),
      )
    }
    if adjustment.amount_minor <= 0 {
      findings.push(
        make_finding(
          InvalidAmount,
          Error,
          Adjustment,
          adjustment.id,
          adjustment.order_id,
          "adjustment amount must be positive",
        ),
      )
    }
    if is_blank(adjustment.reason) {
      findings.push(
        make_finding(
          MissingReference,
          Warning,
          Adjustment,
          adjustment.id,
          adjustment.order_id,
          "adjustment should carry a reason",
        ),
      )
    }
    if find_order(input, adjustment.order_id) is None {
      findings.push(
        make_finding(
          UnknownOrder,
          Error,
          Adjustment,
          adjustment.id,
          adjustment.order_id,
          "adjustment references an unknown order",
        ),
      )
    }
  }
  ignore(policy)
}

///|
pub fn validate(input : LedgerInput, policy : Policy) -> Array[Finding] {
  let findings : Array[Finding] = []
  validate_orders(input, policy, findings)
  validate_payments(input, policy, findings)
  validate_refunds(input, policy, findings)
  validate_adjustments(input, policy, findings)
  findings
}
