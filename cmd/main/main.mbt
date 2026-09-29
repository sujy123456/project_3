///|
fn main {
  let result = @ledgerweave.reconcile(
    @ledgerweave.demo_input(),
    @ledgerweave.default_policy(),
    40,
  )
  println(@ledgerweave.render_summary(result))
  println("")
  println(@ledgerweave.render_balances(result))
  println(@ledgerweave.render_findings(result))
}
