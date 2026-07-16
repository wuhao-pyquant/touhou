# 《百鬼夜祭异变》v3 执行收敛修订 v3.1

生效日期：2026-07-16。

本修订只替换剩余 M2 与 M3–M8 的执行、模型路由、审查和测试方式。《Windows 1.0 成熟化计划 v3》的产品范围、里程碑顺序和质量门槛保持冻结；`docs/production/readiness.json` 仍是唯一进度账本。不得据此生成另一份总体计划。

## 1. 执行目标

### INFRA-M2.5 admission gate

在任何新 M2 证据/审查票和 M3-M8 票之前，release lead 必须通过一次缓存的 session admission gate。它验证 Codex/Godot 可执行文件及版本、项目/worktree/temp 根与写权限、磁盘空间、profile bridge/native 兼容性、残留项目进程、Godot mutex 和最小 Codex `final.json` 探针。fingerprint 不变时同一批次复用；任一输入改变必须重跑。

新票一律使用 `execution_contract_version=2` 的结构化 `execution_checks`，只能声明 `git_diff_check`、Python unittest 或受控 Godot test。不得携带任意 shell/PowerShell acceptance command；已快照旧票只允许原 run 的读取和续跑。bridge 将失败分为 TASK_FAILURE、ENVIRONMENT_FAILURE、TRANSPORT_FAILURE；仅前者使用 repair escalation，后两者保留原 model、reasoning、session、worktree 和 round，且最多一次有界重试。相同 `root_run_id + repair_round` 采用 single-flight；原 CLI 存活或 final.json grace 未结束时拒绝重复 resume。`status=completed` 的 `GATE: REPAIR`/`GATE: REPAIR_AUTHORIZED` 是已完成审查证据，不触发 normalization Agent。

模型生效/恢复、`status/gate` 规范化、CLI/session 核对、路径/编码/BOM/引号预检、Godot 进程清理、根证书警告分类、`final.json` grace 等待和纯传输重试均属于主流程机械职责，一律不得创建 Agent。外部 CLI Agent 存活期间，release lead 每 2–5 分钟向主对话发送一次阶段心跳。

- 以可运行闭环和验收证据为调度单位，不以文件、字段、提交或报告数量为单位。
- 复用已有候选提交、worktree 和证据；已覆盖的内容不得重新拆票实现。
- 不再创建泛化 gap review。缺口只能写入当前里程碑的单一验收矩阵，并分配给现有闭环。
- 最多同时运行三个独立 CLI Agent；常态为两个无冲突写任务，第三个槽位仅在确有证据采集或审查需求时启用。
- 共享 `main.gd`、固定时钟、RNG、快照和 BulletWorld 所有权冲突必须串行；不同关卡的数据与资源可并行。
- 新 ticket 使用 profile 顶层默认模型。只有原 ticket 失败后才原地续跑升级；成功或终止的链不会改变下一张 ticket 的默认等级。
- 每次 CLI 运行必须从 rollout/bridge 证据核对实际 model 与 model_reasoning_effort；声明值和实际值不一致时直接失败。
- 新 ticket 必须声明 `max_edit_test_loops`。实现票最大为 2；证据捕获、盲评和深审票为 0。达到上限仍失败时本次调用立即返回，不允许继续开放式调试。

## 2. M2 立即进入收口模式

本节状态基于主分支 `d1b2fc3`。后续只更新 readiness 中三个闭环的状态，不再派 gap-review Agent。

| 闭环 | 已有输入 | 唯一剩余交付 | 执行身份 | 验收与审查 |
|---|---|---|---|---|
| A. 玩法运行时 | 场地拓扑已合并；得分路线契约已合并；`7e21cf0` 是被最终门禁阻塞的候选，只作参考，不得直接合并 | 修正已知快照 B1/B2 问题，把确定性掉落、路线结算和真实 `main.gd` 回调一次接通 | `gameplay_systems / Sol high` 负责得分语义；只有确需改公共运行时接缝时，才串行追加 `core_simulation / Sol xhigh` 子票 | 在可写 worktree 运行得分路线聚焦断言与 Stage 2 主流程断言；触及主场景才加一次启动烟雾。A 全部完成后只做一次 `bounded_reviewer / Terra high` 审查链 |
| B. 练习与回放 | `d177ff0` 的六阶段练习契约是候选输入 | 实际第二关/六阶段入口、最小可用菜单、回放中的关卡/阶段身份与兼容拒绝 | `profile_replay_ui / Terra high`；只有确认存在公共快照接口缺口时才请求 `core_simulation`，不得预先升级 | 运行练习契约、回放身份和入口聚焦测试；因涉及持久身份，完成后做一次 `bounded_reviewer / Terra high` 审查链 |
| C. 运行证据包 | `f458c5a` 的证据分析器是候选输入 | 基于 A、B 合并后的真实运行生成 Normal/Hard 轨迹、热力图、弹量曲线、六机体击破时间、得分账本、帧时间和录像 | `test_performance / Terra high` 生成可重复指标；只有脚本无法采集真实操作录像时才追加 `qa_operator / Terra medium` | 此闭环不再做代码静态复审；完成后执行 M2 唯一一次全量性能基准，再由 `playtest_critic / Sol high` 对完整证据包盲评一次 |

旧 `M2-stage2-score-route-runtime` 修复链已经耗尽并得到阻塞结论，不再继续为旧候选创建复审或 normalization 票。闭环 A 应从当前主分支建立一张后继交付票，把旧候选、最终阻塞报告和两个已知缺陷作为输入；这张票的目标是完成真实主流程闭环，不是重新审计旧实现。若文件所有权要求拆成 gameplay/core 两张串行子票，它们共享一个 A 闭环门禁，中间不各自派审查 Agent。

### M2 最终门禁

1. A、B 的静态检查和小型 probe 全部通过并合并后，才创建 C 的最终 capture ticket。
2. 最终 capture ticket 只能写 `evidence/m2-stage2/**`，禁止修改源码、测试脚本和证据工具；Normal/Hard 最终捕获各运行一次。
3. A、B、C 全部完成并合并后，`release_lead` 运行一次 M2 里程碑回归。
4. M2 性能基准只运行一次；若失败，只复测失败项及直接相邻场景。
5. 录像、热力图、曲线、账本和可玩构建齐全后，`playtest_critic` 才运行一次，且只能读取已整理的证据包。
6. 盲评失败只允许一次定向修订；复核使用同一 reviewer profile 和原证据包，只看修订片段与更新证据，不重新盲评整包。
7. 所有门禁通过后直接把 readiness 的 M2 改为 `completed`；不得再创建“最终差距审查”。

## 3. 默认闭环流程

`实现票 → 可写 worktree 聚焦运行验证 → release_lead 路径/diff/证据检查 → 必要时一条独立审查链 → 合并 → 里程碑单次回归`

以下情况默认不派独立审查 Agent：

- ticket、TOML、文档、清单、路径、schema 或报告格式变更；
- 生成物可由确定性脚本重建且行为断言已通过；
- 单一所有权模块内的低风险修复，聚焦测试已覆盖失败路径；
- 冻结设计后的字段级内容落地；其创意质量在批次证据门禁统一判断。

只有以下情况触发独立审查：

- 改变公共运行时接口、固定时钟、RNG、快照或回放确定性；
- 改变存档迁移、Continue/1CC、符卡捕获、资源或得分结算语义；
- 改变导出、安装、权限、许可证或发布边界；
- 实施 Agent 报告尚未解释的高风险残留；
- 到达规定的批次创意门禁、里程碑门禁或最终发布门禁。

普通触发项由 `bounded_reviewer / Terra high` 处理。`mechanical_auditor / Luna medium` 只核验路径、schema、清单和证据完整性，不判断玩法语义。`deep_reviewer / Sol max` 只用于同一行为缺陷在一次原地修复后仍失败、架构冻结争议或最终发布裁决。

每个闭环最多一条审查链：

1. 闭环实现与聚焦运行证据齐全后再审查，不逐提交审查。
2. `GATE: REPAIR` 后由原实施 Agent 在原 session/worktree 修复一次。
3. 使用同一 reviewer profile，只检查修复增量和原证据包中新增加的证据。
4. 同一行为缺陷仍存在时才调用一次 `deep_reviewer`；它只读取失败项、既有日志和最小相关 diff 来裁决边界，不接管实现，也不得重新执行几十条探索命令。
5. schema、顶层 status、报告措辞或缺字段由桥接器直接失败，不得派 Agent 规范化报告。

## 4. 测试触发矩阵

| 改动类型 | Ticket 层 | Milestone 层 | 禁止事项 |
|---|---|---|---|
| 文档、TOML、JSON schema、清单 | 解析、schema、路径和 `git diff --check` | 无 | 不启动 Godot，不派代码审查 |
| GDScript/玩法行为 | 隔离可写 worktree 内一次最小聚焦 Godot 断言 | 合并后一次里程碑回归 | 不由只读 Agent 启动 Godot；不重复跑全套 |
| `main.gd`、autoload、主场景接缝 | 聚焦断言加一次启动烟雾 | 一次里程碑回归 | 不为未触及启动链的改动附加烟雾 |
| RNG、快照、回放、存档 | 受影响契约测试加一条确定性往返测试 | 里程碑回归中的对应分组 | 不重复跑无关关卡或全角色矩阵 |
| 性能 | 只验证局部上限或采样工具可用 | 仅 M2、M5、M8 运行全量基准 | 不在每个 Agent/提交运行全量基准 |
| Release 候选 | 无额外开发期全矩阵 | M8 每个候选只跑一次完整矩阵 | 修复后只复测失败项与邻接范围 |

Godot 验证必须经 `tools/testing/invoke_godot_test.ps1` 受控执行，串行占用项目引擎槽位，并把超时、非零退出、C++ backtrace、`CrashHandlerException` 和 Windows 应用程序错误视为失败。静态检查用于解释运行结果，不能替代可执行证据。

实现票最多允许两次定向 `edit → focused test` 循环；第二次仍失败即返回。最终捕获前可运行静态检查和小型 probe，但最终 Normal/Hard 捕获本身只能各运行一次，且捕获票不得修改源码。盲评只消费整理后的证据包，不承担捕获、修复或源码探索。

## 5. 模型路由

| 工作类型 | Agent / 默认模型 | 使用边界 |
|---|---|---|
| 路径、schema、清单、scope、证据完整性 | `mechanical_auditor / Luna medium` | 只读机械核验 |
| 普通代码审查 | `bounded_reviewer / Terra high` | 每闭环至多一条审查链 |
| 关卡数据、Boss/台词落地 | `content_runtime / Terra high` | 使用冻结设计，不改公共运行时 |
| 演出和素材集成 | `art_runtime / Terra high` | 不改玩法语义 |
| 聚焦测试、遥测和性能工具 | `test_performance / Terra high` | 全量性能仅 M2/M5/M8 |
| 练习、回放、存档和菜单 | `profile_replay_ui / Terra high` | 失败后才升 Sol high、再升 Sol xhigh |
| 得分、资源、Continue/1CC 跨系统语义 | `gameplay_systems / Sol high` | 不承担普通复审 |
| 发布协调和门禁 | `release_lead / Sol high` | 维护唯一 readiness |
| 盲评完整证据包 | `playtest_critic / Sol high` | 每内容批次一次 |
| 固定时钟、RNG、碰撞、快照、公共弹幕架构 | `core_simulation / Sol xhigh` | 不承担字段修补或普通复审 |
| 批次编舞冻结与一次创意门禁 | `danmaku_director / Sol xhigh` | 不亲自处理后续字段级实现 |
| 重复行为失败、架构/最终放行裁决 | `deep_reviewer / Sol max` | 不能作为常规保险审查 |
| 导出/安装与包操作 | `build_release / Terra medium`、`qa_operator / Terra medium` | 只在发布闭环使用 |

`core_simulation` 的修复梯度为 `xhigh → max → max`；第二轮保持 max，不再错误降回 xhigh。所有升级只覆盖当前续跑 turn，闭环结束后新 ticket 自动回到顶层默认等级。

## 6. M3–M8 批次执行

| 里程碑 | 交付组织 | 默认调度 | 唯一批次门禁 |
|---|---|---|---|
| M3：第一、三关 | 先冻结一个双关设计包，再按不冲突文件并行实现两关 | `danmaku_director xhigh` 一次；`content_runtime Terra high` 两个关卡实现；需要公共接口时才串行 `core_simulation` | 一次双关回归、一个含两关分项的盲评证据包；不逐波次或逐符卡复审 |
| M4：第四、五关 | 与 M3 相同，节奏固定拍点接口先冻结 | `danmaku_director xhigh` 一次；`content_runtime Terra high` 两关；节奏运行时确有公共缺口才用 `core_simulation` | 一次双关回归和一次批次盲评；不对每个拍点派审查 |
| M5：第六关、最终 Boss、对话结局 | 一个完整终局闭环，不拆成阶段字段票 | `danmaku_director xhigh` 冻结变形语法；`content_runtime Terra high` 实现；`gameplay_systems Sol high` 仅处理跨系统结算 | 一次 M5 回归、一次全量性能基准、一次终局盲评 |
| M6：完整游戏模式 | 服务层与菜单层最多两个闭环；共享存档/回放 schema 先冻结 | `profile_replay_ui Terra high` 为默认；`gameplay_systems Sol high` 只负责 Continue/1CC 等规则 | 一次持久化/回放审查链和一次 M6 回归，不逐菜单复审 |
| M7：视听整合 | 按“弹幕可读性、Boss 演出、背景/UI”资源组交付 | `art_runtime Terra high`；仅明确位图缺口使用 imagegen | 每个发生变化的资源组一次运行截图检查；玩法未变时不重跑盲评或全量性能 |
| M8：Windows 1.0 | 构建、包操作和发布裁决三个闭环 | `build_release Terra medium`、`qa_operator Terra medium`、`release_lead Sol high` | 每个 RC 一次完整矩阵；修复后只复测失败项；`deep_reviewer max` 最多一次最终裁决 |

M3–M5 的一份批次盲评必须分别给每关打分，因此仍覆盖每关质量，但只启动一个 `playtest_critic` 会话。只有完整证据包不齐或自动门禁失败时才延后盲评，不得用静态源码猜测“好玩程度”。

## 7. 防止流程再次膨胀

- readiness 只维护里程碑和当前三个闭环状态；不得为同一状态生成第二份计划。
- 一个闭环通常只有一张主实现票；只有文件所有权冲突时才拆串行子票。
- 不为“可能存在的缺口”派 Agent。必须先指出未满足的冻结验收行、现有证据和唯一责任人。
- 不为通过的提交追加“保险深审”。高模型只由风险类型或重复失败触发。
- 不为报告格式、schema、scope、路径或退出码错误派修复 Agent；桥接器应立即失败并由 `release_lead` 修正 ticket 或工具。
- 不为模型/推理等级核对、默认等级恢复、`status/gate` 修正、CLI/session 核对、路径编码预检、进程清理、证书警告、延迟落盘或传输重试派 Agent。
- 不允许实现 Agent 在一次调用内超过两次定向 edit-test；不允许最终 capture ticket 修改源码；不允许盲评或深审重新展开实现探索。
- 不因并发槽位空闲而启动任务；并行只用于没有共享文件所有权的真实工作。
- 每个里程碑只在结束时更新 readiness；日常进度写入当前闭环状态，不改写计划正文。
