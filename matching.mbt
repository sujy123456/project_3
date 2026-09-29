///| Payment allocation produces a deterministic, non-mutating matching plan.

///|
pub(all) enum AllocationState {
  Applied
  UnmatchedPayment
  OverAllocation
  CurrencyConflict
  IgnoredPayment
} derive(Debug, Eq)

///|
pub(all) struct PaymentAllocation {
  payment_id : String
  order_id : String
  currency : String
  allocated_minor : Int
  state : AllocationState
  note : String
} derive(Debug, Eq)

///|
pub(all) struct AllocationPlan {
  allocations : Array[PaymentAllocation]
  unallocated_minor : Int
  allocated_minor : Int
  ignored_minor : Int
  valid : Bool
} derive(Debug, Eq)

///|
pub(all) struct MatchingCandidate {
  payment_id : String
  order_id : String
  score : Int
  reason : String
} derive(Debug, Eq)

///|
pub fn allocation_state_label(state : AllocationState) -> String {
  match state {
    Applied => "applied"
    UnmatchedPayment => "unmatched_payment"
    OverAllocation => "over_allocation"
    CurrencyConflict => "currency_conflict"
    IgnoredPayment => "ignored_payment"
  }
}

///|
pub fn empty_allocation_plan() -> AllocationPlan {
  {
    allocations: [],
    unallocated_minor: 0,
    allocated_minor: 0,
    ignored_minor: 0,
    valid: true,
  }
}

///|
pub fn remaining_expected(balance : OrderBalance) -> Int {
  let remaining = balance.expected_minor + balance.refunded_minor
  if remaining < 0 {
    0
  } else {
    remaining
  }
}

///|
pub fn captured_payment_amount(payment : PaymentRecord) -> Int {
  if payment.status == Captured {
    payment.amount_minor
  } else {
    0
  }
}

///|
pub fn is_eligible_payment(payment : PaymentRecord) -> Bool {
  payment.status == Captured &&
  payment.amount_minor > 0 &&
  !is_blank(payment.order_id)
}

///|
pub fn payment_matches_order(
  payment : PaymentRecord,
  order : OrderRecord,
) -> Bool {
  payment.order_id == order.id && payment.currency == order.currency
}

///|
pub fn candidate_score(payment : PaymentRecord, order : OrderRecord) -> Int {
  if payment.order_id == order.id && payment.currency == order.currency {
    100
  } else if payment.order_id == order.id {
    25
  } else if payment.currency == order.currency &&
    payment.amount_minor == order.amount_minor {
    10
  } else {
    0
  }
}

///|
pub fn matching_candidates(
  input : LedgerInput,
  payment : PaymentRecord,
) -> Array[MatchingCandidate] {
  let candidates : Array[MatchingCandidate] = []
  for order in input.orders {
    let score = candidate_score(payment, order)
    if score > 0 {
      let reason = if score == 100 {
        "exact order and currency"
      } else if score == 25 {
        "order id matches but currency differs"
      } else {
        "currency and amount heuristic"
      }
      candidates.push({
        payment_id: payment.id,
        order_id: order.id,
        score,
        reason,
      })
    }
  }
  candidates
}

///|
pub fn best_candidate(
  input : LedgerInput,
  payment : PaymentRecord,
) -> MatchingCandidate? {
  let candidates = matching_candidates(input, payment)
  if candidates.is_empty() {
    return None
  }
  let mut best = candidates[0]
  for candidate in candidates {
    if candidate.score > best.score {
      best = candidate
    }
  }
  Some(best)
}

///|
fn allocation_for_ignored(payment : PaymentRecord) -> PaymentAllocation {
  {
    payment_id: payment.id,
    order_id: payment.order_id,
    currency: payment.currency,
    allocated_minor: 0,
    state: IgnoredPayment,
    note: "payment is not captured or has a non-positive amount",
  }
}

///|
fn allocation_for_unknown(payment : PaymentRecord) -> PaymentAllocation {
  {
    payment_id: payment.id,
    order_id: payment.order_id,
    currency: payment.currency,
    allocated_minor: 0,
    state: UnmatchedPayment,
    note: "no order exists for payment reference",
  }
}

///|
fn allocation_for_currency_conflict(
  payment : PaymentRecord,
) -> PaymentAllocation {
  {
    payment_id: payment.id,
    order_id: payment.order_id,
    currency: payment.currency,
    allocated_minor: 0,
    state: CurrencyConflict,
    note: "payment currency differs from target order currency",
  }
}

///|
fn allocation_for_applied(
  payment : PaymentRecord,
  amount : Int,
) -> PaymentAllocation {
  {
    payment_id: payment.id,
    order_id: payment.order_id,
    currency: payment.currency,
    allocated_minor: amount,
    state: Applied,
    note: "captured payment allocated to outstanding amount",
  }
}

///|
fn allocation_for_excess(
  payment : PaymentRecord,
  amount : Int,
) -> PaymentAllocation {
  {
    payment_id: payment.id,
    order_id: payment.order_id,
    currency: payment.currency,
    allocated_minor: amount,
    state: OverAllocation,
    note: "payment exceeds remaining expected amount",
  }
}

///|
fn plan_add(
  plan : AllocationPlan,
  allocation : PaymentAllocation,
) -> AllocationPlan {
  let allocations = plan.allocations.copy()
  allocations.push(allocation)
  let mut next = { ..plan, allocations, }
  match allocation.state {
    Applied =>
      next = {
        ..next,
        allocated_minor: next.allocated_minor + allocation.allocated_minor,
      }
    IgnoredPayment =>
      next = {
        ..next,
        ignored_minor: next.ignored_minor + allocation.allocated_minor,
      }
    UnmatchedPayment =>
      next = {
        ..next,
        unallocated_minor: next.unallocated_minor + allocation.allocated_minor,
        valid: false,
      }
    OverAllocation =>
      next = {
        ..next,
        unallocated_minor: next.unallocated_minor + allocation.allocated_minor,
        valid: false,
      }
    CurrencyConflict => next = { ..next, valid: false, }
  }
  next
}

///|
fn projected_remaining(
  balances : Array[OrderBalance],
  allocations : Array[PaymentAllocation],
  order_id : String,
) -> Int {
  match find_balance(balances, order_id) {
    None => 0
    Some(balance) => {
      let mut remaining = remaining_expected(balance)
      for allocation in allocations {
        if allocation.order_id == order_id && allocation.state == Applied {
          remaining = remaining - allocation.allocated_minor
        }
      }
      if remaining < 0 {
        0
      } else {
        remaining
      }
    }
  }
}

///|
pub fn allocate_payments(
  input : LedgerInput,
  result : ReconciliationResult,
) -> AllocationPlan {
  let mut plan = empty_allocation_plan()
  for payment in input.payments {
    if !is_eligible_payment(payment) {
      plan = plan_add(plan, allocation_for_ignored(payment))
      continue
    }
    match find_order(input, payment.order_id) {
      None => {
        let allocation = {
          ..allocation_for_unknown(payment),
          allocated_minor: payment.amount_minor,
        }
        plan = plan_add(plan, allocation)
      }
      Some(order) => {
        if order.currency != payment.currency {
          plan = plan_add(plan, allocation_for_currency_conflict(payment))
          continue
        }
        let remaining = projected_remaining(
          result.balances,
          plan.allocations,
          order.id,
        )
        let allocated = if payment.amount_minor < remaining {
          payment.amount_minor
        } else {
          remaining
        }
        if allocated > 0 {
          plan = plan_add(plan, allocation_for_applied(payment, allocated))
        }
        let excess = payment.amount_minor - allocated
        if excess > 0 {
          plan = plan_add(plan, allocation_for_excess(payment, excess))
        }
      }
    }
  }
  plan
}

///|
pub fn allocations_for_payment(
  allocations : Array[PaymentAllocation],
  payment_id : String,
) -> Array[PaymentAllocation] {
  let selected : Array[PaymentAllocation] = []
  for allocation in allocations {
    if allocation.payment_id == payment_id {
      selected.push(allocation)
    }
  }
  selected
}

///|
pub fn allocations_for_order(
  allocations : Array[PaymentAllocation],
  order_id : String,
) -> Array[PaymentAllocation] {
  let selected : Array[PaymentAllocation] = []
  for allocation in allocations {
    if allocation.order_id == order_id {
      selected.push(allocation)
    }
  }
  selected
}

///|
pub fn allocated_for_order(
  allocations : Array[PaymentAllocation],
  order_id : String,
) -> Int {
  let mut total = 0
  for allocation in allocations {
    if allocation.order_id == order_id && allocation.state == Applied {
      total = total + allocation.allocated_minor
    }
  }
  total
}

///|
pub fn excess_for_payment(
  allocations : Array[PaymentAllocation],
  payment_id : String,
) -> Int {
  let mut total = 0
  for allocation in allocations {
    if allocation.payment_id == payment_id && allocation.state == OverAllocation {
      total = total + allocation.allocated_minor
    }
  }
  total
}

///|
pub fn unmatched_allocations(plan : AllocationPlan) -> Array[PaymentAllocation] {
  let selected : Array[PaymentAllocation] = []
  for allocation in plan.allocations {
    if allocation.state == UnmatchedPayment ||
      allocation.state == CurrencyConflict {
      selected.push(allocation)
    }
  }
  selected
}

///|
pub fn over_allocations(plan : AllocationPlan) -> Array[PaymentAllocation] {
  let selected : Array[PaymentAllocation] = []
  for allocation in plan.allocations {
    if allocation.state == OverAllocation {
      selected.push(allocation)
    }
  }
  selected
}

///|
pub fn ignored_allocations(plan : AllocationPlan) -> Array[PaymentAllocation] {
  let selected : Array[PaymentAllocation] = []
  for allocation in plan.allocations {
    if allocation.state == IgnoredPayment {
      selected.push(allocation)
    }
  }
  selected
}

///|
pub fn allocation_plan_is_consistent(plan : AllocationPlan) -> Bool {
  let mut applied = 0
  let mut unallocated = 0
  let mut ignored = 0
  let mut valid = true
  for allocation in plan.allocations {
    if allocation.allocated_minor < 0 || is_blank(allocation.payment_id) {
      return false
    }
    match allocation.state {
      Applied => applied = applied + allocation.allocated_minor
      IgnoredPayment => ignored = ignored + allocation.allocated_minor
      UnmatchedPayment => {
        unallocated = unallocated + allocation.allocated_minor
        valid = false
      }
      OverAllocation => {
        unallocated = unallocated + allocation.allocated_minor
        valid = false
      }
      CurrencyConflict => valid = false
    }
  }
  plan.allocated_minor == applied &&
  plan.unallocated_minor == unallocated &&
  plan.ignored_minor == ignored &&
  plan.valid == valid
}

///|
pub fn render_allocation_plan(plan : AllocationPlan) -> String {
  let mut output = "PAYMENT | ORDER | AMOUNT | STATE | NOTE\n"
  for allocation in plan.allocations {
    output = output +
      "\{allocation.payment_id} | \{allocation.order_id} | \{allocation.allocated_minor} | \{allocation_state_label(allocation.state)} | \{allocation.note}\n"
  }
  output +
  "allocated=\{plan.allocated_minor} unallocated=\{plan.unallocated_minor} ignored=\{plan.ignored_minor} valid=\{plan.valid}"
}
