///| Review workflow turns machine findings into owned and auditable cases.

///|
pub(all) enum ReviewState {
  Open
  Investigating
  Resolved
  Dismissed
} derive(Debug, Eq)

///|
pub(all) enum ReviewDecision {
  ConfirmedIssue
  DataCorrection
  BusinessException
  FalsePositive
  NoDecision
} derive(Debug, Eq)

///|
pub(all) struct ReviewCase {
  case_id : String
  finding : Finding
  priority : Int
  state : ReviewState
  owner : String
  opened_day : Int
  updated_day : Int
  decision : ReviewDecision
  resolution_note : String
} derive(Debug, Eq)

///|
pub(all) struct ReviewQueue {
  cases : Array[ReviewCase]
  next_sequence : Int
} derive(Debug, Eq)

///|
pub(all) struct ReviewSummary {
  open : Int
  investigating : Int
  resolved : Int
  dismissed : Int
  unassigned : Int
  overdue : Int
} derive(Debug, Eq)

///|
pub(all) struct AssignmentRule {
  code : FindingCode
  owner : String
} derive(Debug, Eq)

///|
pub fn empty_review_queue() -> ReviewQueue {
  { cases: [], next_sequence: 1, }
}

///|
pub fn empty_review_summary() -> ReviewSummary {
  {
    open: 0,
    investigating: 0,
    resolved: 0,
    dismissed: 0,
    unassigned: 0,
    overdue: 0,
  }
}

///|
pub fn review_state_label(state : ReviewState) -> String {
  match state {
    Open => "open"
    Investigating => "investigating"
    Resolved => "resolved"
    Dismissed => "dismissed"
  }
}

///|
pub fn review_decision_label(decision : ReviewDecision) -> String {
  match decision {
    ConfirmedIssue => "confirmed_issue"
    DataCorrection => "data_correction"
    BusinessException => "business_exception"
    FalsePositive => "false_positive"
    NoDecision => "no_decision"
  }
}

///|
pub fn priority_for_severity(severity : Severity) -> Int {
  match severity {
    Error => 1
    Warning => 2
    Info => 3
  }
}

///|
pub fn priority_label(priority : Int) -> String {
  if priority <= 1 {
    "critical"
  } else if priority == 2 {
    "high"
  } else if priority == 3 {
    "normal"
  } else {
    "low"
  }
}

///|
fn case_id(sequence : Int) -> String {
  "CASE-" + sequence.to_string()
}

///|
pub fn new_review_case(
  finding : Finding,
  sequence : Int,
  opened_day : Int,
) -> ReviewCase {
  {
    case_id: case_id(sequence),
    finding,
    priority: priority_for_severity(finding.severity),
    state: Open,
    owner: "",
    opened_day,
    updated_day: opened_day,
    decision: NoDecision,
    resolution_note: "",
  }
}

///|
pub fn enqueue_finding(
  queue : ReviewQueue,
  finding : Finding,
  opened_day : Int,
) -> ReviewQueue {
  let cases = queue.cases.copy()
  cases.push(new_review_case(finding, queue.next_sequence, opened_day))
  { cases, next_sequence: queue.next_sequence + 1, }
}

///|
pub fn enqueue_findings(
  queue : ReviewQueue,
  findings : Array[Finding],
  opened_day : Int,
) -> ReviewQueue {
  let mut next = queue
  for finding in findings {
    next = enqueue_finding(next, finding, opened_day)
  }
  next
}

///|
pub fn queue_from_result(
  result : ReconciliationResult,
  opened_day : Int,
) -> ReviewQueue {
  enqueue_findings(
    empty_review_queue(),
    warning_or_higher_findings(result.findings),
    opened_day,
  )
}

///|
pub fn find_case_index(cases : Array[ReviewCase], wanted : String) -> Int {
  for index = 0; index < cases.length(); index = index + 1 {
    if cases[index].case_id == wanted {
      return index
    }
  }
  -1
}

///|
pub fn find_review_case(
  cases : Array[ReviewCase],
  wanted : String,
) -> ReviewCase? {
  let index = find_case_index(cases, wanted)
  if index < 0 {
    None
  } else {
    Some(cases[index])
  }
}

///|
pub fn is_terminal_state(state : ReviewState) -> Bool {
  state == Resolved || state == Dismissed
}

///|
pub fn can_transition(from : ReviewState, to : ReviewState) -> Bool {
  match from {
    Open => to == Investigating || to == Resolved || to == Dismissed
    Investigating => to == Open || to == Resolved || to == Dismissed
    Resolved => to == Investigating
    Dismissed => to == Investigating
  }
}

///|
pub fn transition_case(
  queue : ReviewQueue,
  wanted : String,
  target : ReviewState,
  updated_day : Int,
) -> ReviewQueue {
  let cases = queue.cases.copy()
  let index = find_case_index(cases, wanted)
  if index < 0 {
    return queue
  }
  let current = cases[index]
  if !can_transition(current.state, target) || updated_day < current.updated_day {
    return queue
  }
  cases[index] = { ..current, state: target, updated_day, }
  { ..queue, cases, }
}

///|
pub fn assign_case(
  queue : ReviewQueue,
  wanted : String,
  owner : String,
  updated_day : Int,
) -> ReviewQueue {
  let cases = queue.cases.copy()
  let index = find_case_index(cases, wanted)
  if index < 0 || is_blank(owner) {
    return queue
  }
  let current = cases[index]
  if updated_day < current.updated_day {
    return queue
  }
  cases[index] = { ..current, owner, updated_day, }
  { ..queue, cases, }
}

///|
pub fn set_case_priority(
  queue : ReviewQueue,
  wanted : String,
  priority : Int,
  updated_day : Int,
) -> ReviewQueue {
  let cases = queue.cases.copy()
  let index = find_case_index(cases, wanted)
  if index < 0 || priority < 1 || priority > 4 {
    return queue
  }
  let current = cases[index]
  if updated_day < current.updated_day {
    return queue
  }
  cases[index] = { ..current, priority, updated_day, }
  { ..queue, cases, }
}

///|
pub fn decide_case(
  queue : ReviewQueue,
  wanted : String,
  decision : ReviewDecision,
  note : String,
  updated_day : Int,
) -> ReviewQueue {
  let cases = queue.cases.copy()
  let index = find_case_index(cases, wanted)
  if index < 0 || decision == NoDecision || is_blank(note) {
    return queue
  }
  let current = cases[index]
  if !is_terminal_state(current.state) || updated_day < current.updated_day {
    return queue
  }
  cases[index] = { ..current, decision, resolution_note: note, updated_day, }
  { ..queue, cases, }
}

///|
pub fn reopen_case(
  queue : ReviewQueue,
  wanted : String,
  updated_day : Int,
) -> ReviewQueue {
  let transitioned = transition_case(queue, wanted, Investigating, updated_day)
  let cases = transitioned.cases.copy()
  let index = find_case_index(cases, wanted)
  if index < 0 {
    return transitioned
  }
  let current = cases[index]
  if current.state != Investigating {
    return transitioned
  }
  cases[index] = { ..current, decision: NoDecision, resolution_note: "", }
  { ..transitioned, cases, }
}

///|
pub fn auto_assign(
  queue : ReviewQueue,
  rules : Array[AssignmentRule],
  updated_day : Int,
) -> ReviewQueue {
  let mut next = queue
  for case in queue.cases {
    if !is_blank(case.owner) {
      continue
    }
    for rule in rules {
      if case.finding.code == rule.code {
        next = assign_case(next, case.case_id, rule.owner, updated_day)
        break
      }
    }
  }
  next
}

///|
pub fn cases_for_owner(
  cases : Array[ReviewCase],
  owner : String,
) -> Array[ReviewCase] {
  let selected : Array[ReviewCase] = []
  for case in cases {
    if case.owner == owner {
      selected.push(case)
    }
  }
  selected
}

///|
pub fn cases_for_order(
  cases : Array[ReviewCase],
  order_id : String,
) -> Array[ReviewCase] {
  let selected : Array[ReviewCase] = []
  for case in cases {
    if case.finding.order_id == order_id {
      selected.push(case)
    }
  }
  selected
}

///|
pub fn cases_for_state(
  cases : Array[ReviewCase],
  state : ReviewState,
) -> Array[ReviewCase] {
  let selected : Array[ReviewCase] = []
  for case in cases {
    if case.state == state {
      selected.push(case)
    }
  }
  selected
}

///|
pub fn open_cases(cases : Array[ReviewCase]) -> Array[ReviewCase] {
  let selected : Array[ReviewCase] = []
  for case in cases {
    if !is_terminal_state(case.state) {
      selected.push(case)
    }
  }
  selected
}

///|
pub fn case_age(case : ReviewCase, current_day : Int) -> Int {
  if current_day <= case.opened_day {
    0
  } else {
    current_day - case.opened_day
  }
}

///|
pub fn is_overdue(
  case : ReviewCase,
  current_day : Int,
  max_age_days : Int,
) -> Bool {
  !is_terminal_state(case.state) && case_age(case, current_day) > max_age_days
}

///|
pub fn overdue_cases(
  cases : Array[ReviewCase],
  current_day : Int,
  max_age_days : Int,
) -> Array[ReviewCase] {
  let selected : Array[ReviewCase] = []
  for case in cases {
    if is_overdue(case, current_day, max_age_days) {
      selected.push(case)
    }
  }
  selected
}

///|
pub fn review_summary(
  queue : ReviewQueue,
  current_day : Int,
  max_age_days : Int,
) -> ReviewSummary {
  let mut summary = empty_review_summary()
  for case in queue.cases {
    match case.state {
      Open => summary = { ..summary, open: summary.open + 1, }
      Investigating =>
        summary = { ..summary, investigating: summary.investigating + 1, }
      Resolved => summary = { ..summary, resolved: summary.resolved + 1, }
      Dismissed => summary = { ..summary, dismissed: summary.dismissed + 1, }
    }
    if is_blank(case.owner) && !is_terminal_state(case.state) {
      summary = { ..summary, unassigned: summary.unassigned + 1, }
    }
    if is_overdue(case, current_day, max_age_days) {
      summary = { ..summary, overdue: summary.overdue + 1, }
    }
  }
  summary
}

///|
pub fn sort_cases_by_priority(cases : Array[ReviewCase]) -> Array[ReviewCase] {
  let sorted = cases.copy()
  for outer = 0; outer < sorted.length(); outer = outer + 1 {
    for inner = 0; inner + 1 < sorted.length() - outer; inner = inner + 1 {
      let left = sorted[inner]
      let right = sorted[inner + 1]
      if left.priority > right.priority ||
        (left.priority == right.priority && left.opened_day > right.opened_day) {
        sorted[inner] = right
        sorted[inner + 1] = left
      }
    }
  }
  sorted
}

///|
pub fn render_review_case(case : ReviewCase) -> String {
  "\{case.case_id} | \{priority_label(case.priority)} | \{review_state_label(case.state)} | \{case.owner} | \{finding_code_label(case.finding.code)} | \{case.finding.order_id}"
}

///|
pub fn render_review_queue(queue : ReviewQueue) -> String {
  let mut output = "CASE | PRIORITY | STATE | OWNER | CODE | ORDER\n"
  for case in sort_cases_by_priority(queue.cases) {
    output = output + render_review_case(case) + "\n"
  }
  output
}

///|
pub fn review_queue_is_consistent(queue : ReviewQueue) -> Bool {
  let ids : Array[String] = []
  for case in queue.cases {
    if is_blank(case.case_id) || contains_string(ids, case.case_id) {
      return false
    }
    if case.updated_day < case.opened_day ||
      case.priority < 1 ||
      case.priority > 4 {
      return false
    }
    if is_terminal_state(case.state) &&
      case.decision == NoDecision &&
      !is_blank(case.resolution_note) {
      return false
    }
    ids.push(case.case_id)
  }
  true
}
