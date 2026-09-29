///| CSV adapters for LedgerWeave's documented import schemas.

///| Quoted commas and doubled quotes are supported; malformed values become records

///|
/// that the normal validation stage reports rather than causing partial mutation.
pub fn parse_csv(text : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  for raw in text.split("\n") {
    let line = raw.to_owned().trim().to_owned()
    if line != "" {
      rows.push(parse_csv_line(line))
    }
  }
  rows
}

///|
fn parse_csv_line(line : String) -> Array[String] {
  let cells : Array[String] = []
  let chars = line.to_array()
  let mut field = ""
  let mut quoted = false
  let mut index = 0
  while index < chars.length() {
    let char = chars[index]
    if char == '"' {
      if quoted && index + 1 < chars.length() && chars[index + 1] == '"' {
        field = field + "\""
        index = index + 1
      } else {
        quoted = !quoted
      }
    } else if char == ',' && !quoted {
      cells.push(field.trim().to_owned())
      field = ""
    } else {
      field = field + char.to_string()
    }
    index = index + 1
  }
  cells.push(field.trim().to_owned())
  cells
}

///|
fn column_index(headers : Array[String], name : String) -> Int {
  for index = 0; index < headers.length(); index = index + 1 {
    if headers[index] == name {
      return index
    }
  }
  -1
}

///|
fn field(row : Array[String], index : Int) -> String {
  if index < 0 || index >= row.length() {
    ""
  } else {
    row[index]
  }
}

///|
fn parse_int(text : String) -> Int {
  let mut value = 0
  let mut seen = false
  for char in text.trim().to_owned().to_array() {
    let code = char.to_int()
    if code >= 48 && code <= 57 {
      value = value * 10 + code - 48
      seen = true
    } else {
      return 0
    }
  }
  if seen {
    value
  } else {
    0
  }
}

///|
fn order_status(text : String) -> OrderStatus {
  match text {
    "paid" => Paid
    "cancelled" => Cancelled
    "refunded" => Refunded
    _ => Pending
  }
}

///|
fn payment_status(text : String) -> PaymentStatus {
  match text {
    "voided" => Voided
    "failed" => Failed
    _ => Captured
  }
}

///|
fn direction(text : String) -> AdjustmentDirection {
  match text {
    "debit" => Debit
    _ => Credit
  }
}

///|
pub fn parse_orders_csv(text : String) -> Array[OrderRecord] {
  let rows = parse_csv(text)
  let records : Array[OrderRecord] = []
  if rows.is_empty() {
    return records
  }
  let headers = rows[0]
  let id = column_index(headers, "id")
  let account = column_index(headers, "account_id")
  let currency = column_index(headers, "currency")
  let amount = column_index(headers, "amount_minor")
  let created = column_index(headers, "created_day")
  let status = column_index(headers, "status")
  for index = 1; index < rows.length(); index = index + 1 {
    let row = rows[index]
    records.push({
      id: field(row, id),
      account_id: field(row, account),
      currency: field(row, currency),
      amount_minor: parse_int(field(row, amount)),
      created_day: parse_int(field(row, created)),
      status: order_status(field(row, status)),
    })
  }
  records
}

///|
pub fn parse_payments_csv(text : String) -> Array[PaymentRecord] {
  let rows = parse_csv(text)
  let records : Array[PaymentRecord] = []
  if rows.is_empty() {
    return records
  }
  let headers = rows[0]
  let id = column_index(headers, "id")
  let order_id = column_index(headers, "order_id")
  let currency = column_index(headers, "currency")
  let amount = column_index(headers, "amount_minor")
  let received = column_index(headers, "received_day")
  let status = column_index(headers, "status")
  for index = 1; index < rows.length(); index = index + 1 {
    let row = rows[index]
    records.push({
      id: field(row, id),
      order_id: field(row, order_id),
      currency: field(row, currency),
      amount_minor: parse_int(field(row, amount)),
      received_day: parse_int(field(row, received)),
      status: payment_status(field(row, status)),
    })
  }
  records
}

///|
pub fn parse_refunds_csv(text : String) -> Array[RefundRecord] {
  let rows = parse_csv(text)
  let records : Array[RefundRecord] = []
  if rows.is_empty() {
    return records
  }
  let headers = rows[0]
  let id = column_index(headers, "id")
  let order_id = column_index(headers, "order_id")
  let currency = column_index(headers, "currency")
  let amount = column_index(headers, "amount_minor")
  let refunded = column_index(headers, "refunded_day")
  let reason = column_index(headers, "reason")
  for index = 1; index < rows.length(); index = index + 1 {
    let row = rows[index]
    records.push({
      id: field(row, id),
      order_id: field(row, order_id),
      currency: field(row, currency),
      amount_minor: parse_int(field(row, amount)),
      refunded_day: parse_int(field(row, refunded)),
      reason: field(row, reason),
    })
  }
  records
}

///|
pub fn parse_adjustments_csv(text : String) -> Array[AdjustmentRecord] {
  let rows = parse_csv(text)
  let records : Array[AdjustmentRecord] = []
  if rows.is_empty() {
    return records
  }
  let headers = rows[0]
  let id = column_index(headers, "id")
  let order_id = column_index(headers, "order_id")
  let currency = column_index(headers, "currency")
  let amount = column_index(headers, "amount_minor")
  let day = column_index(headers, "day")
  let adjustment_direction = column_index(headers, "direction")
  let reason = column_index(headers, "reason")
  for index = 1; index < rows.length(); index = index + 1 {
    let row = rows[index]
    records.push({
      id: field(row, id),
      order_id: field(row, order_id),
      currency: field(row, currency),
      amount_minor: parse_int(field(row, amount)),
      day: parse_int(field(row, day)),
      direction: direction(field(row, adjustment_direction)),
      reason: field(row, reason),
    })
  }
  records
}

///|
pub fn parse_ledger_csv(
  orders : String,
  payments : String,
  refunds : String,
  adjustments : String,
) -> LedgerInput {
  {
    orders: parse_orders_csv(orders),
    payments: parse_payments_csv(payments),
    refunds: parse_refunds_csv(refunds),
    adjustments: parse_adjustments_csv(adjustments),
  }
}

///|
/// Parses a non-negative day number for command adapters. Invalid input becomes zero.
pub fn parse_day(text : String) -> Int {
  parse_int(text)
}
