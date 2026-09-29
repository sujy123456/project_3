///|
fn balance_for_order(
  input : LedgerInput,
  order : OrderRecord,
  policy : Policy,
) -> OrderBalance {
  let captured = sum_captured(input, order.id)
  let refunded = sum_refunded(input, order.id)
  let adjustments = sum_adjustments(input, order.id)
  let expected = order.amount_minor + adjustments
  let outstanding = expected - captured + refunded
  let resolution = if refunded > captured {
    RefundRisk
  } else if outstanding > policy.amount_tolerance_minor {
    AwaitingPayment
  } else if outstanding < -policy.amount_tolerance_minor {
    OverCollected
  } else {
    Settled
  }
  {
    order_id: order.id,
    expected_minor: expected,
    captured_minor: captured,
    refunded_minor: refunded,
    adjustments_minor: adjustments,
    outstanding_minor: outstanding,
    resolution,
  }
}

///|
fn balance_findings(
  input : LedgerInput,
  balance : OrderBalance,
  current_day : Int,
  policy : Policy,
  findings : Array[Finding],
) -> Unit {
  match find_order(input, balance.order_id) {
    None => ()
    Some(order) => {
      if balance.refunded_minor > balance.captured_minor {
        findings.push(
          make_finding(
            RefundExceedsPayment,
            Error,
            Order,
            order.id,
            order.id,
            "refund total exceeds captured payment total",
          ),
        )
      }
      if balance.outstanding_minor < -policy.amount_tolerance_minor {
        findings.push(
          make_finding(
            Overpaid,
            Error,
            Order,
            order.id,
            order.id,
            "captured amount exceeds expected amount",
          ),
        )
      }
      if balance.outstanding_minor > policy.amount_tolerance_minor {
        findings.push(
          make_finding(
            Underpaid,
            Warning,
            Order,
            order.id,
            order.id,
            "order remains underpaid",
          ),
        )
        if current_day - order.created_day > policy.max_open_age_days {
          findings.push(
            make_finding(
              OpenPastDue,
              Warning,
              Order,
              order.id,
              order.id,
              "open order exceeded configured age",
            ),
          )
        }
      }
    }
  }
}

///|
pub fn reconcile(
  input : LedgerInput,
  policy : Policy,
  current_day : Int,
) -> ReconciliationResult {
  let findings = validate(input, policy)
  let balances : Array[OrderBalance] = []
  for order in input.orders {
    let balance = balance_for_order(input, order, policy)
    balances.push(balance)
    balance_findings(input, balance, current_day, policy, findings)
  }
  let mut valid = true
  for finding in findings {
    if finding.severity == Error {
      valid = false
    }
  }
  { balances, findings, valid, }
}
