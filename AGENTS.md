# 百鬼夜祭异变执行约束

本仓库以《百鬼夜祭异变 Windows 1.0 成熟化计划 v3》为冻结范围。除 `release_lead` 外，任何 Agent 都不得重写总体计划、扩展 1.0 范围或改变里程碑顺序。剩余 M2 与 M3–M8 的详细执行方式见 `docs/production/execution-convergence-v3.1.md`。

## 1. 调度与准入

- 指定模型或推理强度的任务只能由 `tools/agents/invoke_agent.ps1` 调用独立 Codex CLI；`.codex/agents/*.toml` 是模型、推理强度、沙箱和职责的唯一来源。每次运行必须从 rollout/bridge 证据核对实际 model 与 effort。
- 被调度 Agent 是叶子工作者：不得生成子 Agent、重写计划、提交、变基、合并、推送或删除 worktree；写任务在桥接器创建的 `.worktrees/` 中执行，只有 `release_lead` 合并。
- 新 M2 证据/审查票及 M3–M8 票启动前必须通过可缓存的 session admission preflight：CLI/Godot 路径与版本、可写根、磁盘、残留进程、Godot mutex、profile 兼容性和最小 `final.json` 探针。fingerprint 变化时重跑。
- 最多同时运行三个独立 CLI Agent，常态只开两个无文件冲突的写任务；共享 `main.gd`、固定时钟、RNG、快照、BulletWorld 或公共运行时接口的工作必须串行。
- 以下机械操作由 `release_lead` 或桥接器本地完成，不得创建 Agent：核对模型升级/默认恢复、修正 `status/gate`、检查 CLI/session、路径/编码/BOM/引号预检、Godot 进程清理、根证书警告分类、等待 `final.json` 和纯传输重试。
- 外部 CLI Agent 存活期间，`release_lead` 每 2–5 分钟向主对话发送一次阶段/循环数/阻塞心跳，不派 Agent 获取状态。

## 2. Ticket、失败与续跑

- 新 ticket 必须使用 `execution_contract_version=2`，声明 allowed/forbidden paths、dependency commit、结构化 `execution_checks`、`max_repair_rounds` 和 `max_edit_test_loops`；禁止任意 PowerShell `acceptance_commands`。旧快照只为原 session/worktree 续跑保留兼容性。
- 实现票 `max_edit_test_loops` 最大为 2；capture、盲评和只读审查票必须为 0。第二次定向 `edit → focused test` 仍失败就返回，不得在单次调用内继续开放式调试。
- bridge 必须区分 `TASK_FAILURE`、`ENVIRONMENT_FAILURE`、`TRANSPORT_FAILURE`。只有任务失败消耗 repair round 或升级模型；环境/传输失败只允许一次同身份、同 session/worktree/round 的有界重试。
- 修复使用 `-ResumeRun <run-id> -EscalationLevel <n>` 续跑原 Agent、session、worktree、branch 和 ticket；只能使用原 profile 的连续 `[[repair_escalations]]`。升级只覆盖当前 turn，闭环结束后新 ticket 恢复 profile 顶层默认等级。
- 同一 `root_run_id + repair_round` 只能有一个 resume；必须确认原 CLI/session 已退出并经过 `final.json` grace 后才能续跑。

## 3. 所有权与用户改动

- 不得修改 ticket 允许路径之外的文件，也不得吸收、还原或提交主工作树的既有用户改动，尤其是 `audio/**/*.import`。
- 公共运行时接口由 `core_simulation` 独占；并行内容 Agent 只能使用已冻结接口。

## 4. Git 主线与工作树生命周期

- 本地 `master` 是唯一持续集成主线。除旧 session 的原地续跑外，所有新 ticket 的 `dependency_commit` 必须来自当时的 `master` HEAD；不得把 `codex/*` 里程碑分支长期当作第二主线。
- 写 ticket 通过聚焦验收后，`release_lead` 必须立即把接受的候选提交 cherry-pick 到 `master`，不得等待 M8 或积累到下一里程碑。未通过的候选不得进入 `master`。
- 候选进入 `master` 且续跑链关闭后，`release_lead` 必须在同一收尾回合调用 `tools/agents/finalize_agent_worktree.ps1`。该工具必须确认 worktree 干净、无活动 run，并且 ticket 提交与 `master` 补丁等价后，才能删除 worktree 和分支。
- 仍有 patch-unique 提交的分支默认拒绝清理。只有已记录明确取代提交和取代理由、且取代提交已在 `master` 中时，才能以 superseded 方式关闭；不得用强制删除掩盖漏合并。
- 失败 worktree 只在同一修复链仍可续跑时保留。链成功、明确 blocked 或被取代后，先保存 `.agent-runs` 证据，再由 `release_lead` 处置脏生成物并关闭，不得跨里程碑无限保留。
- 里程碑完成门禁包括：readiness 提交已在 `master`、无该里程碑的活动 Agent、无已关闭 ticket 的残留 worktree/分支。`git worktree prune` 是本地机械收尾，不得另派 Agent。
- 推送 `origin/master`、创建发布标签或发布包仍需用户明确要求或 M8 发布授权；本地主线合并不自动扩大为远程发布。

## 5. 审查、测试与证据

- Ticket 层只运行直接相关的最小测试；触及启动、autoload、主场景或真实运行接缝时才加一次烟雾检查。Milestone 合并后运行一次回归，Release 候选运行一次完整矩阵；性能全量基准只在 M2、M5、M8 执行。
- GDScript/行为验证在隔离可写 worktree 中运行受控 Godot；文档、TOML、schema、路径任务和 Windows `read_only` Agent 不得启动 Godot。同一项目 Godot 验收串行，超时/崩溃时终止完整进程树。
- 默认不派独立审查。只有公共运行时/确定性/回放、存档迁移、得分资源语义、发布边界或里程碑创意/发布门禁才触发；低风险改动在聚焦测试、scope 和 diff 通过后由 `release_lead` 直接合并。
- 每个闭环最多一条审查链：首次 `GATE: REPAIR` 由原实施 Agent 原地修复一次，审查者只复核增量；同一行为缺陷仍失败才调用一次 `deep_reviewer`。禁止泛化 gap review、逐提交静态审查、保险深审和 report-normalization Agent。
- 普通代码审查使用 `bounded_reviewer / Terra high`，机械核验使用 `mechanical_auditor / Luna medium`；`core_simulation`、`danmaku_director`、`deep_reviewer` 不承担普通字段修补或常规复审。
- 最终 capture ticket 只能写整理后的证据目录，禁止改源码、测试和工具；Normal/Hard 只在静态检查与小型 probe 全部通过后各捕获一次。`playtest_critic` 只读证据包；`deep_reviewer` 只读失败项、既有日志和最小 diff，不重新展开探索。
- 不以文件存在、源码文本或精确弹数替代行为验证。解析错误、测试失败、超时、Godot 非零退出、C++ backtrace、`CrashHandlerException` 或 Windows 错误弹窗必须返回失败；历史绿灯不能代替本次证据。

## 6. 项目基线

- Godot 4.7；内部游戏区域 720x960；Windows Release 目标稳定 60 FPS。
- 1.0 仅包含 Normal/Hard、六关故事、关卡/符卡练习、回放和成绩记录。Easy、Lunatic、Extra Stage 延后。
