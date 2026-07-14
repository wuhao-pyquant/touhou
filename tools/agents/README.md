# Codex CLI Agent 桥接器

桥接器从 `.codex/agents/<agent>.toml` 读取 Agent 的默认模型、推理强度、沙箱和修复梯度。调用方不能在命令行任意覆盖模型。

首次执行：

```powershell
tools/agents/invoke_agent.ps1 `
  -Agent content_runtime `
  -Ticket tickets/M2-stage2.json
```

失败后的原地修复：

```powershell
tools/agents/invoke_agent.ps1 `
  -Agent content_runtime `
  -ResumeRun <failed-run-id> `
  -EscalationLevel 1 `
  -RepairInstruction "只修复上一轮报告中的失败项"
```

续跑规则：

- 只接受状态为 `failed` 或具备可恢复 session 的 `bridge_error` 运行。
- Agent、ticket 快照、Codex thread、worktree、branch 和基准提交必须与父运行一致。
- `EscalationLevel` 必须等于父运行轮次加一，且同时受 ticket 的 `max_repair_rounds` 与同一 profile 的 `[[repair_escalations]]` 限制。
- `codex exec resume` 的模型覆盖只作用于当前 repair turn；profile 顶层默认值不会被修改。
- 成功运行关闭该续跑链，不能再次 resume；下一张新 ticket 从 profile 顶层默认模型与推理强度开始。
- 每个 turn 生成独立的 `.agent-runs/<run-id>/` 证据目录，并记录 `parent_run_id`、`root_run_id`、`repair_round`、实际模型和实际推理强度。
- 失败的只读 worktree 也会保留以支持原地续跑；成功的只读 worktree 按默认清理策略移除。

原实施 Agent 的第一轮修复仍失败时，由 `release_lead` 调用 `deep_reviewer` 做只读裁决。若裁决允许下一轮修复，继续 resume 原 Agent，而不是把实现任务改派给 reviewer。
