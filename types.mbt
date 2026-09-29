///|
/// LedgerWeave's stable domain vocabulary. Amounts are always integer minor units.
pub(all) enum RecordKind {
  Order
  Payment
  Refund
  Adjustment
} derive(Debug, Eq)

///|
pub(all) enum OrderStatus {
  Pending
  Paid
  Cancelled
  Refunded
} derive(Debug, Eq)

///|
pub(all) enum PaymentStatus {
  Captured
  Voided
  Failed
} derive(Debug, Eq)

///|
pub(all) enum AdjustmentDirection {
  Credit
  Debit
} derive(Debug, Eq)

///|
pub(all) struct OrderRecord {
  id : String
  account_id : String
  currency : String
  amount_minor : Int
  created_day : Int
  status : OrderStatus
} derive(Debug, Eq)

///|
pub(all) struct PaymentRecord {
  id : String
  order_id : String
  currency : String
  amount_minor : Int
  received_day : Int
  status : PaymentStatus
} derive(Debug, Eq)

///|
pub(all) struct RefundRecord {
  id : String
  order_id : String
  currency : String
  amount_minor : Int
  refunded_day : Int
  reason : String
} derive(Debug, Eq)

///|
pub(all) struct AdjustmentRecord {
  id : String
  order_id : String
  currency : String
  amount_minor : Int
  day : Int
  direction : AdjustmentDirection
  reason : String
} derive(Debug, Eq)

///|
pub(all) struct LedgerInput {
  orders : Array[OrderRecord]
  payments : Array[PaymentRecord]
  refunds : Array[RefundRecord]
  adjustments : Array[AdjustmentRecord]
} derive(Debug, Eq)

///|
pub(all) struct Policy {
  allowed_currencies : Array[String]
  amount_tolerance_minor : Int
  max_payment_lag_days : Int
  max_open_age_days : Int
  permit_cancelled_payment : Bool
} derive(Debug, Eq)

///|
pub(all) enum Severity {
  Info
  Warning
  Error
} derive(Debug, Eq)

///|
pub(all) enum FindingCode {
  DuplicateOrderId
  DuplicatePaymentId
  DuplicateRefundId
  DuplicateAdjustmentId
  InvalidAmount
  InvalidCurrency
  UnknownOrder
  CurrencyMismatch
  PaymentAfterDeadline
  PaymentForCancelledOrder
  RefundExceedsPayment
  Overpaid
  Underpaid
  OpenPastDue
  PaymentVoided
  MissingReference
} derive(Debug, Eq)

///|
pub(all) struct Finding {
  code : FindingCode
  severity : Severity
  record_kind : RecordKind
  record_id : String
  order_id : String
  message : String
} derive(Debug, Eq)

///|
pub(all) enum Resolution {
  Settled
  AwaitingPayment
  OverCollected
  RefundRisk
  NeedsReview
} derive(Debug, Eq)

///|
pub(all) struct OrderBalance {
  order_id : String
  expected_minor : Int
  captured_minor : Int
  refunded_minor : Int
  adjustments_minor : Int
  outstanding_minor : Int
  resolution : Resolution
} derive(Debug, Eq)

///|
pub(all) struct ReconciliationResult {
  balances : Array[OrderBalance]
  findings : Array[Finding]
  valid : Bool
} derive(Debug, Eq)

///|
pub fn default_policy() -> Policy {
  {
    allowed_currencies: ["CNY", "USD", "EUR"],
    amount_tolerance_minor: 0,
    max_payment_lag_days: 30,
    max_open_age_days: 30,
    permit_cancelled_payment: false,
  }
}

///|
pub fn empty_input() -> LedgerInput {
  { orders: [], payments: [], refunds: [], adjustments: [], }
}
