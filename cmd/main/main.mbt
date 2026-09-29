///|
fn print_result(result : @ledgerweave.ReconciliationResult) -> Unit {
  println(@ledgerweave.render_summary(result))
  println("")
  println(@ledgerweave.render_balances(result))
  println(@ledgerweave.render_findings(result))
}

///|
async fn main {
  let argv = @env.args()
  let args = argv[1:]
  if args.length() == 0 || args[0] == "demo" {
    print_result(
      @ledgerweave.reconcile(
        @ledgerweave.demo_input(),
        @ledgerweave.default_policy(),
        40,
      ),
    )
    return
  }
  if args.length() != 5 {
    println(
      "usage: ledgerweave <orders.csv> <payments.csv> <refunds.csv> <adjustments.csv> <current-day>",
    )
    println("or:    ledgerweave demo")
    return
  }
  let orders = @fs.read_file(args[0]).text()
  let payments = @fs.read_file(args[1]).text()
  let refunds = @fs.read_file(args[2]).text()
  let adjustments = @fs.read_file(args[3]).text()
  let day = @ledgerweave.parse_day(args[4])
  let input = @ledgerweave.parse_ledger_csv(
    orders, payments, refunds, adjustments,
  )
  print_result(
    @ledgerweave.reconcile(input, @ledgerweave.default_policy(), day),
  )
}
