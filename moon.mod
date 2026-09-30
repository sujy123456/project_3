// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "sujy123456/ledgerweave"

version = "0.3.0"

readme = "README.md"

repository = "https://github.com/sujy123456/project_3"

license = "Apache-2.0"

keywords = [ "ledger", "reconciliation", "data-quality", "csv" ]

preferred_target = "native"

description = "Deterministic multi-source business ledger reconciliation and exception attribution."

import {
  "moonbitlang/async@0.21.3",
}
