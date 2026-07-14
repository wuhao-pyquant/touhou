# 百鬼夜祭异变执行约束

本仓库以《百鬼夜祭异变 Windows 1.0 成熟化计划 v3》为冻结范围。除 `release_lead` 外，任何 Agent 都不得重写总体计划、扩展 1.0 产品范围或自行改变里程碑顺序。

## Agent 调度

- 需要指定模型或推理强度的任务只能通过 `tools/agents/invoke_agent.ps1` 调用独立 Codex CLI。
- `.codex/agents/*.toml` 是 Agent 模型、推理强度、沙箱和职责的唯一来源。
- 被调度 Agent 是叶子工作者：不得生成子 Agent、创建额外计划或自动合并分支。
- 写任务必须在桥接器创建的 `.worktrees/` 隔离工作树中执行；主工作树只由 `release_lead` 合并。
- 每个 ticket 必须声明允许路径、禁止路径、基准提交、验收命令和最大修复轮数。
- 首次失败后的修复必须用 `-ResumeRun <run-id> -EscalationLevel <n>` 续跑原 Agent 的同一 session、worktree、branch 和 ticket；不得创建替代 Agent 或新工作树。
- 修复轮次只能使用该 Agent profile 的 `[[repair_escalations]]` 连续梯度，不能临时从命令行任意指定模型。
- 修复模型仅覆盖当前续跑 turn，不改写 profile 顶层默认值；ticket 成功后续跑链关闭，下一张新 ticket 自动恢复顶层默认模型与推理强度。

## 所有权与用户改动

- 不得修改 ticket 允许路径之外的文件。
- 不得吸收、还原或提交主工作树中既有的用户改动，尤其是 `audio/**/*.import`。
- 公共运行时接口由 `core_simulation` 独占；并行内容 Agent 只能使用已冻结接口。
- Agent 不得提交、变基、合并、推送或删除工作树；这些动作由 `release_lead` 完成。

## 实施与验证

- Ticket 层只运行直接相关测试和一个烟雾检查。
- Milestone 合并后运行一次里程碑回归；Release 候选只运行一次完整矩阵。
- 不以文件存在、源码文本匹配或精确弹数替代行为验证。
- 同一缺陷由原实施 Agent 在原 session/worktree 中修复一次；该续跑仍失败才交给 `deep_reviewer`。若审查后允许第二轮修复，仍由原 Agent 继续，不切换 Agent 身份。
- 性能全量基准只在 M2、M5、M8 执行。
- 所有测试失败、解析错误、超时和引擎错误都必须返回非零退出码。

## 项目基线

- Godot：4.7，内部游戏区域 720x960，目标 Windows Release 60 FPS。
- 1.0 仅包含 Normal/Hard、六关故事、关卡/符卡练习、回放和成绩记录。
- Easy、Lunatic、Extra Stage 不属于 1.0。
