# 《百鬼夜祭异变》v3 执行收敛修订 v3.1

生效日期：2026-07-16。
产品优先级修订：2026-07-26。

本修订替换剩余 M2 与 M3–M8 的执行、模型路由、审查和测试方式，并规定产品实现顺序。《Windows 1.0 成熟化计划 v3》的 Windows 1.0 最终范围保持不变；`docs/production/readiness.json` 仍是唯一进度账本。不得据此生成另一份总体计划。

## 0. 先建立 Hard 参考路线

当前唯一优先级是先让 `miko / ofuda_trace（巫女 A）+ hard` 成为六关真实可玩的参考路线。Normal 和其余五机体仍属于 Windows 1.0 最终范围，但在参考路线六关贯通前不得消耗主要实现、审查或全量测试资源。

- “可加载”“控制器无 hard error”“无敌脚本跑完”“热力图生成成功”都不是可玩性证据。
- 每关先在关卡练习中完成一次真人或真人录制输入的 Hard 通关：允许 Miss 和 Bomb，不允许 Continue、无敌、传送、跳阶段、自动避弹或专为证明通过而修改判定。
- 六关分别通过后，只运行一次从第一关到结局的连续 Hard 1CC 参考捕获。失败只修复实际失败关及相邻接缝，不重新捕获已经通过的独立关卡。
- 自动回放、固定路线机器人和性能采样只用于确定性、崩溃、弹量和性能诊断，不得代替上述人工可玩证据。
- 参考路线先建立清楚、有发展、有收束的敌群与弹幕语法，再校准躲避空间、预告、阶段时长、Boss HP、资源供给和输入手感。追分路线不能妨碍普通生存路线。
- “弹幕丰富”不等于弹量更大。每关应使用数量受控、职责稳定的弹形与速度层级，通过发射角度、队形、节奏、运动变化和分层组合形成变化；不得用同类子弹长时间滞留、无关机制同时叠加或不可见发射源制造复杂度。
- 取消“六机体 Boss 击破时间差必须在 ±15%”这一产品硬门槛。后续机体只要求机制真实、可通关、没有明显失效或极端拖时；允许因风险、射程、追踪和清杂能力产生有意义的击破时间差。
- 第二关旧 M2 证据只保留为工程与性能诊断。2026-07-26 的实际运行核对已经证明它不能支持“第二关可玩”的结论，因此 M2 回到 `repair_required`。
- M3–M5 先生产 Hard 参考路线；第六关和一次六关连续 1CC 通过后，才在 M5 内完成 Normal 与其余五机体的广度收口，然后进入 M6。

Godot 编辑器、运行态树、属性、输入、截图、错误和场景操作优先使用项目已安装的 Godot MCP/CLI。已有受控测试包装器仍用于确定性断言、超时/进程树管理和发布验收；MCP 的 `sent: true` 只代表已发送，必须以状态读取或截图确认实际效果。存在结构化命令时不得优先使用 `runtime eval`。

## 1. 三轮执行修订合并摘要

| 轮次 | 解决的问题 | 合并后的规则位置 |
|---|---|---|
| 执行收敛 | 逐提交复审、泛化 gap review、高级模型滥用和重复全量测试 | 本文第 3–6 节；根级 `AGENTS.md` 的审查/测试硬规则 |
| INFRA-M2.5 | 路径/编码、Godot 残留、证书误判、传输失败和重复 resume 被误当任务缺陷 | `tools/agents/preflight.py`、bridge failure taxonomy、Godot supervisor 和 single-flight |
| 有界收口 | Agent 无限 edit-test、机械任务另派 Agent、capture 混改源码、盲评/深审重新探索 | ticket `max_edit_test_loops`、根级 capture/reviewer 边界和主对话心跳 |

### 共同执行规则

- 以可运行闭环和验收证据为调度单位；复用已有提交、worktree 和证据，不按文件、字段、报告数量拆票，也不创建泛化 gap review。
- 新 M2 证据/审查票和 M3–M8 票先通过可缓存的 session admission preflight；新票只能使用 v2 结构化 checks，不得携带任意 shell/PowerShell acceptance command。
- bridge 将失败分为 TASK、ENVIRONMENT、TRANSPORT；只有 TASK 消耗 repair round 或模型升级。resume 保持原身份/session/worktree/ticket，并对 `root_run_id + repair_round` single-flight。
- 模型/推理等级核对与恢复、`status/gate`、CLI/session、路径/编码、进程、证书、`final.json` 等机械工作由 bridge/release lead 完成，不创建 Agent。
- 常态最多两个无冲突写 Agent，硬上限三个；共享公共运行时所有权时串行。每次运行从 rollout/bridge 核对实际 model 与 effort。
- 新 ticket 使用 profile 默认等级；失败后才按原 profile 原地升级。实现票最多两次定向 edit-test；capture/盲评/深审票为零次编辑。外部 Agent 运行期间每 2–5 分钟发送一次主对话心跳。

### Git 主线和 ticket 生命周期

- 从 M2 收尾晋升开始，本地 `master` 是唯一绿色集成主线。旧 run 仅可在快照中的原 session/worktree/branch 续跑；所有新 M3–M8 ticket 必须以当时的 `master` HEAD 为 `dependency_commit`。
- `release_lead` 在写 ticket 聚焦验收和必要审查通过后立即提交候选并 cherry-pick 到 `master`。里程碑分支不承担长期集成职责，也不等待 M8 才一次性进入 `master`。
- 接受的候选进入 `master` 后，在同一个 release-lead 收尾回合运行 `tools/agents/finalize_agent_worktree.ps1`。默认先做无副作用预检，确认补丁等价、工作树干净且无活动 session 后，再使用 `-Apply` 删除 worktree 和 ticket 分支。
- patch-unique 分支不能按“已经合并”清理。确属旧实现被替换时，必须同时记录已位于 `master` 的 `SupersededBy` 提交与具体理由；finalizer 机械验证后才能关闭。
- 失败 worktree 的保留期限等于修复链生命周期，不等于项目生命周期。成功、blocked 或 superseded 关闭后只保留 `.agent-runs` 与正式证据，不保留临时分支、失败生成物或 detached 审查工作树。
- 每个里程碑的最后一次机械门禁检查 `master` 已包含 readiness 更新，并且该里程碑没有已关闭的 Agent worktree/branch；这一检查不调用 Agent、不追加回归测试。
- 本地进入 `master` 与远程发布分离。只有用户明确要求或 M8 发布授权时才推送 `origin/master`、创建 Windows 1.0 标签或发布包。

## 2. M2 第二关可玩性修复

旧 A/B/C 闭环的代码、练习/回放和自动证据交付视为已完成的工程输入，不重新审计。当前只增加一个 `Hard 参考路线可玩性` 闭环，不再派 gap-review、报告修复或六机体平衡 Agent。

| 闭环 | 唯一交付 | 默认执行身份 | 聚焦验收 |
|---|---|---|---|
| R2. 第二关 Hard 参考路线 | 重写 `miko / ofuda_trace / hard` 从第二关开始到 Boss 结束的敌群出场、弹幕语法与节奏；先形成可辨识的市集母题，再处理预告、躲避空间、阶段时长、Boss HP 和资源。只有证据指向公共运行时无法表达所需语法时才改架构 | 数据与关卡实现用 `content_runtime / Terra high`；需要冻结创意语法时由 `danmaku_director / Sol xhigh` 一次性给出卡片；跨得分/资源语义才用 `gameplay_systems / Sol high`；公共固定时钟、碰撞或快照缺陷才串行使用 `core_simulation / Sol xhigh` | 一次入口烟雾、受影响母题的小型运行 probe、三个代表段录像检查和一次真人/真人录制输入的 Hard 关卡练习通关；不跑 Normal、不跑六机体 TTK、不先做全量性能 |

当前证据已表明第二关不是单点数值失衡，而是敌人与子弹的内容语法失效，因此允许在冻结的“妖怪市集”身份内重写整关编舞，但不得扩展总体产品范围。`danmaku_director / Sol xhigh` 最多进行一次语法冻结和一次失败录像的定向裁决；不参与字段修补。实现完成后默认由 `release_lead` 直接核对聚焦证据并合并；只有修改公共碰撞/确定性接口或可玩结论存在具体争议时才启用一条 `bounded_reviewer` 审查链。

### R2 敌人与弹幕质量合同

1. **段落句法**：第二关仍分三个清晰段落。第一段单独教授算珠/反弹，第二段教授摊位通道与中速换道，第三段只组合前两段已经学会的语法并引向 Boss。不得每 2–3 秒更换一个互不相关的隐藏规则。
2. **敌人动作**：每类敌人必须有可读的 `入场路径 → 稳定发射窗口 → 击破窗口或退场路径`。同屏不得让三种无关敌人原型同时承担主攻击；子弹必须来自屏幕内可见敌人、Boss 或有明确预告的场景发射器。
3. **弹种职责**：整关使用约 4–6 个视觉差异明确的敌弹家族，但单个波次以一种主弹形为主，最多加入一种已教学的辅助弹形。大圆/算珠负责塑造慢速空间，米弹或小玉负责中速瞄准压力，针弹或碎片只承担有预告的快速标点，延迟/反弹弹必须在改变运动前给出清晰状态提示。
4. **速度层级**：以约 `80–120 px/s` 的慢速塑形、`140–220 px/s` 的中速主压力、`240–320 px/s` 的快速标点构成三个可辨识层级；这些是设计校准区间，不是逐发断言。禁止大量极慢长寿命弹持续堆积后再叠加突发高速层。
5. **母题发展**：每个普通波次和 Boss 阶段只围绕一个能用一句话说明的主母题，按“展示安全形态 → 发展角度/队形/节奏 → 一次组合或反转 → 清场/间歇”推进。丰富度来自母题变化，不来自随机增加发射器。
6. **视觉语义**：同一颜色和弹形在本关保持相近运动含义；反弹方向、延迟激活和高速危险必须在颜色、闪烁、轨迹或音效中至少有一种稳定提示。运行时不得再把不同 `PatternDefinition` 原语无差别降级为同一个 legacy `aimed/spread/downward` 外观。
7. **Boss 递进**：非符先教学核心运动，符卡再改变几何、节奏或组合关系；相邻阶段不得只是换名、加弹数和提速。阶段转换应清场并保留短暂的视觉呼吸，不让上一阶段残留弹遮蔽下一阶段规则。
8. **生存优先**：红蓝黄击破顺序、镜像选择、反弹擦弹等追分机制必须是可选加分层；玩家忽略它们时仍有稳定、可读的生存路线，错误顺序不得制造突发封路。

上述区间和数量用于设计与人工录像检查，不新增依赖精确弹数、固定帧号或源码字符串的断言。若实际画面能以更少弹种形成更强辨识度，优先选择更少而清楚的方案。

### M2 修复门禁

1. capture 前先完成静态解析、入口烟雾和受影响母题的小型 probe；probe 只证明实现接通，不判断好玩。
2. 最终 capture ticket 只能写 `evidence/m2-stage2/playability-hard-miko-a/**`，禁止修改源码、测试和工具。
3. 先各录制一次“第一段前 30 秒、中 Boss 代表阶段、Boss 最终符卡”的 60 FPS 运行片段，检查可见发射源、弹种职责、速度层级、主母题和阶段收束；同一缺陷只做一次定向修订。
4. 最终捕获必须使用正常判定和实际输入；允许 Bomb 和 Miss，但必须无 Continue 完成整关，且记录死亡原因、Bomb 使用、阶段时长和主观阻塞点。能够通关是必要条件，但上述三段仍然混乱或贫乏时不得通过。
5. 捕获成功后只运行受影响的 M2 聚焦回归；旧性能基准不重复，除非修复显著提高峰值弹量、弹池溢出或产生肉眼可见卡顿。
6. 通过后把 M2 改回 `completed` 并进入 M3；不得追加 Normal、其余机体或泛化盲评来拖延晋升。

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

确定性断言、批处理和发布验收必须经 `tools/testing/invoke_godot_test.ps1` 受控执行，串行占用项目引擎槽位，并把超时、非零退出、C++ backtrace、`CrashHandlerException` 和 Windows 应用程序错误视为失败。编辑器与实际游戏的场景、输入、截图、运行树和错误诊断优先使用 Godot MCP/CLI。静态检查用于解释运行结果，不能替代可执行证据。

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
| M3：第一、三关 | 先只落地 `miko / ofuda_trace / hard` 双关参考路线，并复用 R2 的敌人动作、弹种职责、速度层级和母题发展合同 | `danmaku_director xhigh` 一次冻结；`content_runtime Terra high` 两关实现；需要公共接口时才串行 `core_simulation` | 每关三个代表段录像检查和一次 Hard 关卡练习通关证据，再做一次双关聚焦回归；不跑 Normal、其他机体或逐波次复审 |
| M4：第四、五关 | 与 M3 相同，第五关固定拍点先服务 Hard 参考路线；节奏变化仍须保持弹种职责和可见发射意图 | `danmaku_director xhigh` 一次；`content_runtime Terra high` 两关；确有公共节奏接口缺口才用 `core_simulation` | 每关三个代表段录像检查和一次 Hard 关卡练习通关证据，再做一次双关聚焦回归；不对每个拍点派审查 |
| M5：第六关、最终 Boss、对话结局及广度收口 | 先完成第六关参考路线，再进行一次六关连续 Hard 1CC；通过后才补 Normal 与其余五机体 | `danmaku_director xhigh` 冻结变形语法；`content_runtime Terra high` 实现；`gameplay_systems Sol high` 仅处理跨系统结算和后续机体可行性 | 一次六关 Hard 参考捕获；随后用最小矩阵证明 Normal 和其余机体可通关且机制有效，不要求 ±15% TTK；最后一次 M5 回归、全量性能基准和终局盲评 |
| M6：完整游戏模式 | 服务层与菜单层最多两个闭环；共享存档/回放 schema 先冻结 | `profile_replay_ui Terra high` 为默认；`gameplay_systems Sol high` 只负责 Continue/1CC 等规则 | 一次持久化/回放审查链和一次 M6 回归，不逐菜单复审 |
| M7：视听整合 | 按“弹幕可读性、Boss 演出、背景/UI”资源组交付 | `art_runtime Terra high`；仅明确位图缺口使用 imagegen | 每个发生变化的资源组一次运行截图检查；玩法未变时不重跑盲评或全量性能 |
| M8：Windows 1.0 | 构建、包操作和发布裁决三个闭环 | `build_release Terra medium`、`qa_operator Terra medium`、`release_lead Sol high` | 每个 RC 一次完整矩阵；修复后只复测失败项；`deep_reviewer max` 最多一次最终裁决 |

M3、M4 不再启动批次盲评 Agent；每关真实 Hard 通关证据和简短人工游玩记录就是阶段质量门禁。M5 在六关参考路线和广度收口完成后只启动一次 `playtest_critic`，分别给每关打分。不得用静态源码、无敌回放、弹量或机体 TTK 接近程度猜测“好玩程度”。

## 7. 防止流程再次膨胀

- readiness 只维护里程碑和当前三个闭环状态；不得为同一状态生成第二份计划。
- 一个闭环通常只有一张主实现票；只有文件所有权冲突时才拆串行子票。
- 不为“可能存在的缺口”派 Agent。必须先指出未满足的冻结验收行、现有证据和唯一责任人。
- 不因并发槽位空闲而启动任务；并行只用于没有共享文件所有权的真实工作。
- 每个里程碑只在结束时更新 readiness；日常进度写入当前闭环状态，不改写计划正文。
