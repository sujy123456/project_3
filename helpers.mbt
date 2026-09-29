///|
pub fn contains_string(items : Array[String], wanted : String) -> Bool {
  for item in items {
    if item == wanted {
      return true
    }
  }
  false
}

///|
pub fn count_string(items : Array[String], wanted : String) -> Int {
  let mut total = 0
  for item in items {
    if item == wanted {
      total = total + 1
    }
  }
  total
}

///|
pub fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
pub fn is_blank(value : String) -> Bool {
  value.trim() == ""
}

///|
pub fn find_order(input : LedgerInput, order_id : String) -> OrderRecord? {
  for order in input.orders {
    if order.id == order_id {
      return Some(order)
    }
  }
  None
}

///|
pub fn sum_captured(input : LedgerInput, order_id : String) -> Int {
  let mut total = 0
  for payment in input.payments {
    if payment.order_id == order_id && payment.status == Captured {
      total = total + payment.amount_minor
    }
  }
  total
}

///|
pub fn sum_refunded(input : LedgerInput, order_id : String) -> Int {
  let mut total = 0
  for refund in input.refunds {
    if refund.order_id == order_id {
      total = total + refund.amount_minor
    }
  }
  total
}

///|
pub fn sum_adjustments(input : LedgerInput, order_id : String) -> Int {
  let mut total = 0
  for item in input.adjustments {
    if item.order_id == order_id {
      if item.direction == Credit {
        total = total + item.amount_minor
      } else {
        total = total - item.amount_minor
      }
    }
  }
  total
}

///|
pub fn make_finding(
  code : FindingCode,
  severity : Severity,
  record_kind : RecordKind,
  record_id : String,
  order_id : String,
  message : String,
) -> Finding {
  { code, severity, record_kind, record_id, order_id, message, }
}
