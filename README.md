## LedgerWeave 项目申报书

**基本信息**

- 项目名称：LedgerWeave：多源业务流水对账与异常归因引擎
- 参赛者：苏楗轶
- 联系方式：2821775174@qq.com
- GitHub 仓库链接：[https://github.com/sujy123456/project_3](https://github.com/sujy123456/project_3)
- 项目方向：MoonBit 数据处理与业务应用基础设施
- 是否为移植项目：否

**项目简介**

LedgerWeave 是以 MoonBit 实现的多源业务流水对账与异常归因引擎，面向需要核对订单、支付、退款和调整流水的业务系统、数据平台与运营工具。项目以整数最小货币单位处理金额，基于确定性规则识别重复标识、无效金额和币种、未知订单、付款超期、取消订单付款、退款超额、少收、多收和长期未结清等问题，并输出订单余额、异常记录和复核结论。除基础对账外，项目提供输入质量剖析、支付分配计划、复核案例工作流、账龄与账户/币种指标，以及 CSV 和 Markdown 审计导出能力，便于接入 CLI、批处理任务和后续业务系统。

**核心功能范围**

- 提供订单、支付、退款、调整四类强类型流水模型；金额统一使用整数最小单位，避免浮点金额误差；
- 提供确定性对账入口 `reconcile(...)`，计算订单应收、实收、退款、调整与未结清余额；
- 校验重复 ID、空引用、非法金额、非法币种、未知订单、币种不一致、付款时效和取消订单付款等输入与业务规则；
- 识别少收、多收、退款超实收、逾期未结清等异常，并给出严重级别和可追踪归因；
- 支持 CSV 导入订单、支付、退款和调整流水，提供可直接运行的最小示例和原生 CLI；
- 提供按异常代码、严重级别、币种、账户和账龄聚合的分析指标；
- 提供支付分配与匹配计划，覆盖精确付款、部分付款、超额付款、未知订单付款、币种冲突和作废付款；
- 提供复核案例的优先级、归属、状态流转、处理结论与超期检查；
- 提供输入质量报告、复核队列、分配计划及 CSV/Markdown 审计导出；
- 提供 MoonBit 回归测试、CSV 端到端示例及 GitHub Actions 检查、构建、测试流程。

**移植或参考说明**

- 原创/移植情况：项目的领域模型、对账规则、异常归因、支付分配、质量审计、复核工作流和导出实现均为本仓库原创实现，不是对其他项目的移植或简单封装。
- 参考与依赖：运行时使用公开依赖 `moonbitlang/async@0.21.3` 支持 CLI 文件读取；其来源与 Apache-2.0 许可证已在仓库 `THIRD_PARTY_NOTICES.md` 中记录。CI 使用 `hustcer/setup-moonbit@v1` 安装 MoonBit，亦已记录其 MIT 许可证与用途。
- 本项目许可证：Apache License 2.0（OSI 认可），许可证全文位于仓库 `LICENSE`。
- 兼容性说明：项目未复制第三方业务代码、数据集或素材；示例流水均为合成数据，不含个人、真实财务或生产数据。
## 安装、运行与示例

**环境要求**：MoonBit 工具链，`moonc >= 0.10.14`。本项目以 `moonc v0.10.14` 验证。

```bash
moon update
moon check --target native
moon test --target native
moon build --target native
```

仓库包含可直接执行的 CSV 最小样例：

```bash
moon run --target native cmd/main -- \
  examples/csv/orders.csv examples/csv/payments.csv \
  examples/csv/refunds.csv examples/csv/adjustments.csv 40
```

该示例会输出订单余额和异常报告。样例故意包含未知订单付款与已取消订单付款，因此结果为 `REVIEW REQUIRED`；这是对异常归因路径的可复现验证，而非命令失败。

作为库使用时，调用 `@ledgerweave.reconcile(input, policy, current_day)` 获取 `ReconciliationResult`，再按需使用指标、分配、质量审计、复核队列与 CSV/Markdown 导出 API。详见 [架构说明](docs/architecture.md) 与 [申报书](docs/hackathon-application.md)。

## 测试、CI 与质量边界

GitHub Actions 在每次 push 与 pull request 上执行格式检查、依赖更新、原生检查、测试、构建、CSV 端到端示例和包元数据检查。项目以提供的输入和显式策略进行确定性对账；不连接银行、不发起资金操作、不提供税务或审计合规结论。

## 开源许可证与第三方信息

本项目使用 [Apache License 2.0](LICENSE)，属于 OSI 认可的开源许可证。运行时依赖、CI 依赖及其许可证来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
