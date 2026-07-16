# 百鬼夜祭异变执行约束

本仓库以《百鬼夜祭异变 Windows 1.0 成熟化计划 v3》为冻结范围。除 `release_lead` 外，任何 Agent 都不得重写总体计划、扩展 1.0 产品范围或自行改变里程碑顺序。

## Agent 调度

- 从 INFRA-M2.5 起，所有新 M2 证据/审查票和 M3-M8 票在创建前必须通过一次 session admission preflight：已解析的 Codex/Godot 路径与版本、项目/worktree/temp 可写根、磁盘空间、无本项目残留 Codex/Godot、Godot admission mutex、profile bridge/native 兼容性以及最小 Codex `final.json` 探针。相同 fingerprint 可复用同一批次缓存；环境不一致必须重新检查。
- 新 ticket 必须使用 `execution_contract_version=2` 和结构化 `execution_checks`（`git_diff_check`、`python_unittest`、`godot_test`）；禁止任意 PowerShell `acceptance_commands`。已快照的旧 ticket 仅为原 session/worktree 的续跑而保留读取兼容性。
- bridge summary 必须标注 `TASK_FAILURE`、`ENVIRONMENT_FAILURE` 或 `TRANSPORT_FAILURE`。只有 TASK_FAILURE 消耗 repair round 或 profile escalation；环境/传输失败只允许一次同身份、同 session/worktree/round 的有界重试。
- 同一 `root_run_id + repair_round` 只能有一个 resume。桥接器必须先确认原 CLI/session 不存活，并在 `final.json` grace 后再续跑；不得为已完成的 review gate 创建 report-normalization Agent。
- 以下机械操作一律由 `release_lead` 或桥接器本地完成，不得为此创建 Agent：确认模型升级或新 ticket 恢复默认模型、修正 `status/gate`、检查 CLI 版本或 session ID、路径/编码/BOM/引号预检、清理 Godot 残留进程、分类根证书警告、等待延迟落盘的 `final.json`，以及同一失败项的纯传输重试。

- 需要指定模型或推理强度的任务只能通过 `tools/agents/invoke_agent.ps1` 调用独立 Codex CLI。
- `.codex/agents/*.toml` 是 Agent 模型、推理强度、沙箱和职责的唯一来源。
- 被调度 Agent 是叶子工作者：不得生成子 Agent、创建额外计划或自动合并分支。
- 写任务必须在桥接器创建的 `.worktrees/` 隔离工作树中执行；主工作树只由 `release_lead` 合并。
- 每个新 ticket 必须声明允许路径、禁止路径、基准提交、验收命令、最大修复轮数和 `max_edit_test_loops`；实现票该值不得超过 2，证据捕获/只读审查票必须为 0。
- 首次失败后的修复必须用 `-ResumeRun <run-id> -EscalationLevel <n>` 续跑原 Agent 的同一 session、worktree、branch 和 ticket；不得创建替代 Agent 或新工作树。
- 修复轮次只能使用该 Agent profile 的 `[[repair_escalations]]` 连续梯度，不能临时从命令行任意指定模型。
- 修复模型仅覆盖当前续跑 turn，不改写 profile 顶层默认值；ticket 成功后续跑链关闭，下一张新 ticket 自动恢复顶层默认模型与推理强度。
- 剩余 M2 与 M3–M8 必须遵守 `docs/production/execution-convergence-v3.1.md`；它只修订执行方式，不改变 v3 产品范围。
- 最多同时运行三个独立 CLI Agent。默认只开两个无文件冲突的写任务，第三个槽位按需用于证据或审查，不为追求并发而制造任务。
- `core_simulation`、`danmaku_director` 和 `deep_reviewer` 不得承担普通字段修补或常规静态复审；普通代码审查使用 `bounded_reviewer`，机械核验使用 `mechanical_auditor`。
- 每次 CLI 调度都必须从运行证据核对实际 model 与 model_reasoning_effort；与 profile 请求不一致时立即失败，不能用 TOML 声明冒充实际生效值。
- 外部 CLI Agent 运行期间，`release_lead` 必须每 2–5 分钟向主对话发送一次简短心跳；心跳只报告阶段、已用循环数和是否存在阻塞，不派额外 Agent 获取状态。

## 所有权与用户改动

- 不得修改 ticket 允许路径之外的文件。
- 不得吸收、还原或提交主工作树中既有的用户改动，尤其是 `audio/**/*.import`。
- 公共运行时接口由 `core_simulation` 独占；并行内容 Agent 只能使用已冻结接口。
- Agent 不得提交、变基、合并、推送或删除工作树；这些动作由 `release_lead` 完成。

## 实施与验证

- Ticket 层只运行最小的直接相关测试；只有改动启动、autoload、主场景或真实运行接缝时才额外运行一个烟雾检查。
- Milestone 合并后运行一次里程碑回归；Release 候选只运行一次完整矩阵。
- 不以文件存在、源码文本匹配或精确弹数替代行为验证。
- 行为或 GDScript 写任务应在隔离可写 worktree 内先执行一次受控的聚焦 Godot 验证；文档、TOML、纯 schema 或路径任务不得因此启动 Godot。
- 实现阶段最多进行两次定向 `edit → focused test` 循环；第二次仍未满足同一验收项时必须停止并返回失败，不得在单次调用中无限探索、改写或调试。
- 默认不做独立 Agent 审查。只有公共运行时接口、确定性/回放、存档迁移、得分资源语义、发布边界，或里程碑创意/发布门禁才触发审查。
- 每个闭环最多一条独立审查链：首次审查后由原实施 Agent 在原 session/worktree 中修复一次，审查者只复核增量与新证据；同一行为缺陷仍失败才交给 `deep_reviewer`。若深审允许第二轮修复，仍由原 Agent 继续。
- 禁止为普通提交创建泛化 gap review、逐提交静态审查或报告 normalization Agent。路径、schema、scope 和报告格式由桥接器或脚本机械拒绝。
- 最终 capture ticket 的允许写路径只能是整理后的证据目录，必须禁止源码、测试脚本和工具修改；Normal/Hard 最终捕获只能在静态检查和小型 probe 全部通过后各运行一次。
- `playtest_critic` 只能读取已整理好的证据包，不得浏览源码或自行补跑捕获；`deep_reviewer` 只能基于失败项、既有日志和最小相关 diff 裁决，不得重新执行大批探索命令。
- 低风险且范围清晰的改动，在聚焦测试通过、路径边界和 diff 检查通过后，可由 `release_lead` 直接合并，不得为了满足流程数量额外派审查 Agent。
- 性能全量基准只在 M2、M5、M8 执行。
- 所有测试失败、解析错误、超时和引擎错误都必须返回非零退出码。
- Windows 上的 `mode = read_only` Agent 不得启动 Godot；Godot 会写入项目缓存，并已在 Codex 只读沙箱中复现启动期 `signal 11` 原生崩溃。只读审核只检查代码、数据和既有证据，实际 Godot 验收由隔离的可写 worktree 或 `release_lead` 执行。
- 同一项目的 Godot 验收默认串行执行。每次启动前后必须检查本项目 `--headless` 进程；测试超时、原生崩溃或桥接器中断时必须终止整棵进程树，不得留下后台 Godot。
- Godot C++ backtrace、`CrashHandlerException`、Windows 应用程序错误弹窗或非零退出码一律记为本次失败；历史绿灯只能作为旁证，不能冒充本次通过。

## 项目基线

- Godot：4.7，内部游戏区域 720x960，目标 Windows Release 60 FPS。
- 1.0 仅包含 Normal/Hard、六关故事、关卡/符卡练习、回放和成绩记录。
- Easy、Lunatic、Extra Stage 不属于 1.0。
